# E-ink Calendar Service

A Dockerized LAN service that returns a rendered calendar as a **1-bit PNG**. It is intended for an e-ink display that can fetch an HTTP image directly.

## Run it

```sh
cp .env.example .env
docker compose up --build -d
```

The sample source is `data/events.json`. From another device on the LAN, fetch the browser-friendly PNG:

```sh
curl -H "Authorization: Bearer YOUR_TOKEN" -o calendar.png \
  "http://NAS_HOSTNAME_OR_IP:4567/calendar.png?width=800&height=480"
```

The same parameters are available from `/calendar.bmp`. It returns an uncompressed, standard Windows BMP3 file with a 1-bit palette, which is convenient for an embedded client:

```sh
curl -H "Authorization: Bearer YOUR_TOKEN" -o calendar.bmp \
  "http://NAS_HOSTNAME_OR_IP:4567/calendar.bmp?width=800&height=480"
```

At the native panel resolution, the BMP is 48,062 bytes: a 62-byte BMP header/palette followed by 48,000 pixels bytes. Its rows are stored bottom-to-top as normal BMP data, so retain the PNG endpoint for browser previews and use the BMP endpoint only after the ESP32 parser accounts for that row order.

Both image endpoints accept these query parameters:

| Parameter | Default | Notes |
| --- | --- | --- |
| `width` | `800` | 200–2400 pixels |
| `height` | `480` | 200–1600 pixels |
| `date` | today | Anchor ISO date, e.g. `2026-08-29` |
| `view` | `agenda` | `agenda`, `month`, `week`, or `day` |
| `days` | `5` | Agenda only: 5–7 days beginning with `date` |

The endpoint replies with `image/png` and `X-Image-Bit-Depth: 1`. Omit the authorization header only if `CALENDAR_API_TOKEN` is blank. Verify a response with `identify -verbose calendar.png` — it should report a 1-bit PNG.

`/healthz` is intentionally unauthenticated for Docker/NAS health checks. Set `CALENDAR_API_TOKEN` and send `Authorization: Bearer YOUR_TOKEN` for the calendar endpoint; leave it blank only on a trusted LAN.

### Font preset

Set `CALENDAR_FONT` in `.env` to choose the bundled font family:

```dotenv
CALENDAR_FONT=mono # default: DejaVu Sans Mono, terminal-style and most legible at 1-bit
# CALENDAR_FONT=sans
# CALENDAR_FONT=serif
```

`mono` is the recommended e-ink setting. The renderer still converts vector text into a 1-bit bitmap, but its wider, more even strokes survive that conversion better than the proportional face. Restart the container after changing this setting: `docker compose up -d`.

## Google Calendar

The application already includes a Google Calendar provider. Set `CALENDAR_SOURCE=google` and the Google credentials in `.env`:

- Create an OAuth 2.0 Web client in Google Cloud with the Calendar API enabled, and add `https://developers.google.com/oauthplayground` as its authorized redirect URI.
- Complete the one-time OAuth consent flow with the `calendar.readonly` scope and obtain an offline refresh token.
- Put its client ID, client secret, refresh token, and optional calendar ID in `.env`.
- Restart the container: `docker compose up -d`.

The refresh token stays on the NAS, and the container fetches events on each display request. This keeps event data current without storing a separate local calendar copy.

### Multiple calendars

Use `GOOGLE_CALENDARS` to fetch multiple sources. Each entry has the form `label=calendar-id`, and the label is rendered before every event:

```dotenv
GOOGLE_CALENDARS=Syl=primary,Family=family-calendar-id@group.calendar.google.com,Wife=wife-calendar-id@group.calendar.google.com
```

The Google account that created the refresh token must have at least “See all event details” access to each shared calendar. Find each ID in that calendar’s Google Calendar settings under **Integrate calendar**.

`GOOGLE_CALENDAR_ID` remains supported for a single source. Set `GOOGLE_CALENDAR_LABEL` to control its displayed label.

### Views

- `view=agenda` is the default: a high-legibility list of five days beginning today. Set `days=5`, `days=6`, or `days=7` to change its range.
- `view=month` shows a conventional Sunday–Saturday month grid.
- `view=week` shows a seven-column Sunday–Saturday schedule grid.
- `view=day` shows one day as a readable agenda.

All views render the source as a 1-bit PNG. The spacious agenda uses inverse three-letter calendar badges such as `SYL` and `FAM`; grid views use the same short tags to preserve room for event text.

## Development

Install the development dependencies once:

```sh
bundle config set --local path vendor/bundle
bundle install
```

Start a local development server with automatic restart when you save `*.rb`, `*.ru`, or `*.json` files:

```sh
bin/dev
```

It uses port `4568` by default so it can run beside Docker on port `4567`. `bin/dev` reads `.env`, so it uses live Google Calendar data by default. To work with the deterministic sample events instead, run:

```sh
CALENDAR_SOURCE=file CALENDAR_EVENTS_FILE="$PWD/data/events.json" bin/dev
```

Use a fixed date while tuning the layout:

```text
http://localhost:4568/calendar.png?view=agenda&date=2026-08-29&days=5&width=800&height=480
```

## Event-file format

`data/events.json` is a JSON array. Use ISO-8601 timestamps for timed events. An all-day event should end on the following date, matching Google Calendar's exclusive end-date convention.

```json
[
  {
    "calendar": "Family",
    "title": "Dentist",
    "start": "2026-09-02T13:00:00-04:00",
    "end": "2026-09-02T14:00:00-04:00"
  },
  {
    "calendar": "Syl",
    "title": "Vacation",
    "start": "2026-09-04",
    "end": "2026-09-07",
    "all_day": true
  }
]
```
