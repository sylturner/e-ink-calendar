#include <WiFi.h>
#include <HTTPClient.h>
#include <SPI.h>
#include <GxEPD2_BW.h>
#include <gdey/GxEPD2_750_GDEY075T7.h>
#include "secrets.h"

// ---------- Your established e-paper wiring ----------
constexpr int PIN_PWR  = 6;
constexpr int PIN_BUSY = 7;
constexpr int PIN_RST  = 8;
constexpr int PIN_DC   = 9;
constexpr int PIN_CS   = 10;
constexpr int PIN_DIN  = 11; // SPI MOSI
constexpr int PIN_CLK  = 12; // SPI SCK
constexpr int PIN_BUTTON = 4;

constexpr uint16_t SCREEN_WIDTH = 800;
constexpr uint16_t SCREEN_HEIGHT = 480;
constexpr size_t ROW_BYTES = SCREEN_WIDTH / 8; // 100
constexpr size_t BITMAP_BYTES = ROW_BYTES * SCREEN_HEIGHT; // 48,000

constexpr uint32_t REFRESH_INTERVAL_MS = 6UL * 60UL * 60UL * 1000UL;
constexpr uint32_t RETRY_INTERVAL_MS = 5UL * 60UL * 1000UL;
constexpr uint32_t BUTTON_DEBOUNCE_MS = 40;

const char* const VIEWS[] = { "agenda", "day", "week", "month" };
constexpr size_t VIEW_COUNT = sizeof(VIEWS) / sizeof(VIEWS[0]);

size_t currentView = 0;
uint32_t lastRefreshAttempt = 0;
uint32_t nextRefreshDelay = REFRESH_INTERVAL_MS;
bool lastButtonReading = HIGH;
bool stableButtonState = HIGH;
bool buttonArmed = false;
uint32_t buttonStateChangedAt = 0;

GxEPD2_BW<GxEPD2_750_GDEY075T7,
           GxEPD2_750_GDEY075T7::HEIGHT / 4>
  display(GxEPD2_750_GDEY075T7(PIN_CS, PIN_DC, PIN_RST, PIN_BUSY));

bool readExactly(Stream& input, uint8_t* destination, size_t length)
{
  size_t received = 0;

  while (received < length)
  {
    size_t count = input.readBytes(destination + received, length - received);
    if (count == 0) return false;
    received += count;
  }

  return true;
}

uint16_t readU16LE(const uint8_t* bytes)
{
  return uint16_t(bytes[0]) | (uint16_t(bytes[1]) << 8);
}

uint32_t readU32LE(const uint8_t* bytes)
{
  return uint32_t(bytes[0]) |
         (uint32_t(bytes[1]) << 8) |
         (uint32_t(bytes[2]) << 16) |
         (uint32_t(bytes[3]) << 24);
}

void showMessage(const char* title, const String& detail)
{
  display.setFullWindow();
  display.firstPage();

  do
  {
    display.fillScreen(GxEPD_WHITE);
    display.drawRect(20, 20, 760, 440, GxEPD_BLACK);

    display.setTextColor(GxEPD_BLACK);
    display.setTextSize(4);
    display.setCursor(55, 150);
    display.print(title);

    display.setTextSize(2);
    display.setCursor(55, 240);
    display.print(detail);
  }
  while (display.nextPage());
}

String calendarUrlForCurrentView()
{
  return String(CALENDAR_BASE_URL) +
    "?view=" + VIEWS[currentView] +
    "&days=5&width=800&height=480";
}

bool connectToWiFi()
{
  if (WiFi.status() == WL_CONNECTED) return true;

  WiFi.disconnect();
  WiFi.begin(WIFI_NAME, WIFI_PASSWORD);

  Serial.print("Connecting to Wi-Fi");
  const uint32_t startedAt = millis();
  while (WiFi.status() != WL_CONNECTED)
  {
    if (millis() - startedAt > 30000)
    {
      Serial.println(" timed out");
      return false;
    }

    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.print("Wi-Fi connected: ");
  Serial.println(WiFi.localIP());
  return true;
}

bool downloadAndDrawCalendar()
{
  const String calendarUrl = calendarUrlForCurrentView();

  HTTPClient http;
  http.setTimeout(15000);
  http.begin(calendarUrl);
  http.addHeader("Accept", "image/bmp");

  if (strlen(CALENDAR_TOKEN) > 0)
  {
    http.addHeader(
      "Authorization",
      String("Bearer ") + CALENDAR_TOKEN
    );
  }

  Serial.printf("Downloading %s view...\n", VIEWS[currentView]);
  int status = http.GET();
  Serial.printf("HTTP status: %d\n", status);

  if (status != HTTP_CODE_OK)
  {
    http.end();
    showMessage("Calendar download failed", "HTTP status: " + String(status));
    return false;
  }

  Stream* input = http.getStreamPtr();

  // The service sends a 62-byte BMP3 header + palette.
  uint8_t header[62];
  if (!readExactly(*input, header, sizeof(header)))
  {
    http.end();
    showMessage("Calendar download failed", "Could not read BMP header");
    return false;
  }

  bool validBmp =
    header[0] == 'B' &&
    header[1] == 'M' &&
    readU32LE(&header[10]) == 62 &&
    readU32LE(&header[18]) == SCREEN_WIDTH &&
    readU32LE(&header[22]) == SCREEN_HEIGHT &&
    readU16LE(&header[26]) == 1 &&
    readU16LE(&header[28]) == 1 &&
    readU32LE(&header[30]) == 0;

  if (!validBmp)
  {
    http.end();
    showMessage("Calendar download failed", "Unexpected BMP format");
    return false;
  }

  // Use PSRAM when available; regular ESP32 RAM is also sufficient.
  uint8_t* calendar = static_cast<uint8_t*>(ps_malloc(BITMAP_BYTES));
  if (calendar == nullptr)
  {
    calendar = static_cast<uint8_t*>(malloc(BITMAP_BYTES));
  }

  if (calendar == nullptr)
  {
    http.end();
    showMessage("Calendar download failed", "Out of memory");
    return false;
  }

  // BMP palette entry 0 starts at byte 54 and entry 1 at byte 58.
  // GxEPD2 bitmap bits use 1 = black, so invert if BMP uses 0 = black.
  uint16_t palette0Brightness = header[54] + header[55] + header[56];
  uint16_t palette1Brightness = header[58] + header[59] + header[60];
  bool paletteZeroIsBlack = palette0Brightness < palette1Brightness;

  // BMP rows arrive bottom-to-top. Store them top-to-bottom for GxEPD2.
  for (uint16_t bmpRow = 0; bmpRow < SCREEN_HEIGHT; bmpRow++)
  {
    uint8_t* target =
      calendar + (SCREEN_HEIGHT - 1 - bmpRow) * ROW_BYTES;

    if (!readExactly(*input, target, ROW_BYTES))
    {
      free(calendar);
      http.end();
      showMessage("Calendar download failed", "Incomplete BMP data");
      return false;
    }

    if (paletteZeroIsBlack)
    {
      for (size_t i = 0; i < ROW_BYTES; i++)
      {
        target[i] = ~target[i];
      }
    }
  }

  http.end();

  Serial.println("Refreshing e-paper...");
  display.setFullWindow();
  display.firstPage();

  do
  {
    display.fillScreen(GxEPD_WHITE);
    display.drawBitmap(
      0, 0, calendar,
      SCREEN_WIDTH, SCREEN_HEIGHT,
      GxEPD_BLACK
    );
  }
  while (display.nextPage());

  free(calendar);
  Serial.println("Calendar displayed.");
  return true;
}

void refreshCalendar()
{
  lastRefreshAttempt = millis();

  if (!connectToWiFi())
  {
    showMessage("Calendar unavailable", "Wi-Fi connection failed");
    nextRefreshDelay = RETRY_INTERVAL_MS;
    return;
  }

  nextRefreshDelay = downloadAndDrawCalendar()
    ? REFRESH_INTERVAL_MS
    : RETRY_INTERVAL_MS;
}

void checkButton()
{
  const bool reading = digitalRead(PIN_BUTTON);

  if (reading != lastButtonReading)
  {
    buttonStateChangedAt = millis();
    lastButtonReading = reading;
  }

  if ((millis() - buttonStateChangedAt) < BUTTON_DEBOUNCE_MS ||
      reading == stableButtonState)
  {
    return;
  }

  stableButtonState = reading;

  // With INPUT_PULLUP, a pressed button reads LOW.
  if (stableButtonState == HIGH)
  {
    buttonArmed = true;
    Serial.println("Button released; input armed");
  }
  else if (buttonArmed)
  {
    currentView = (currentView + 1) % VIEW_COUNT;
    Serial.printf("Button pressed: switching to %s view\n", VIEWS[currentView]);
    refreshCalendar();
  }
}

void setup()
{
  Serial.begin(115200);
  delay(1000);

  pinMode(PIN_PWR, OUTPUT);
  digitalWrite(PIN_PWR, HIGH);
  delay(200);

  SPI.begin(PIN_CLK, -1, PIN_DIN, PIN_CS);
  display.init(115200);

  WiFi.mode(WIFI_STA);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  delay(20);
  lastButtonReading = digitalRead(PIN_BUTTON);
  stableButtonState = lastButtonReading;
  buttonStateChangedAt = millis();
  buttonArmed = stableButtonState == HIGH;

  Serial.printf(
    "Button input at boot: %s\n",
    stableButtonState == HIGH ? "released (HIGH)" : "pressed (LOW)"
  );

  refreshCalendar();
}

void loop()
{
  checkButton();

  if (millis() - lastRefreshAttempt >= nextRefreshDelay)
  {
    Serial.println("Scheduled refresh");
    refreshCalendar();
  }

  delay(10);
}
