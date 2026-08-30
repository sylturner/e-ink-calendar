# frozen_string_literal: true

require "base64"
require "date"
require "erb"
require "json"
require "open3"
require "sinatra/base"
require "time"
require "ferrum"
require_relative "lib/bitmap_font"

class CalendarApp < Sinatra::Base
  DISPLAY_WIDTH = 800
  DISPLAY_HEIGHT = 480

  configure do
    set :show_exceptions, false
    set :raise_errors, false
  end

  get "/healthz" do
    content_type :json
    { status: "ok", source: CalendarEvents.source_name }.to_json
  end

  # This is the design surface. Open it in a browser while changing the ERB or
  # CSS; /calendar.bmp is the same document after the monochrome conversion.
  get "/calendar.html" do
    require_token!
    content_type "text/html", charset: "utf-8"
    calendar_renderer.html
  end

  get "/calendar.bmp" do
    require_token!
    image = calendar_renderer.bmp

    content_type "image/bmp"
    headers(
      "Cache-Control" => "no-store",
      "Content-Disposition" => "inline; filename=calendar.bmp",
      "X-Image-Bit-Depth" => "1"
    )
    image
  end

  get "/calendar.css" do
    content_type "text/css", charset: "utf-8"
    File.read(CalendarRenderer::STYLESHEET_PATH)
  end

  error ArgumentError do
    halt 400, { error: env["sinatra.error"].message }.to_json
  end

  error StandardError do
    warn env["sinatra.error"].full_message
    halt 500, { error: "Could not render calendar" }.to_json
  end

  private

  def calendar_renderer
    raise ArgumentError, "The calendar resolution is fixed at 800x480" if params.key?("width") || params.key?("height")

    date = parse_date(params.fetch("date", Date.today.iso8601))
    view = params.fetch("view", "agenda")
    raise ArgumentError, "view must be agenda, month, week, or day" unless %w[agenda month week day].include?(view)

    days = view == "agenda" ? integer_param("days", default: 5, min: 5, max: 7) : nil
    from_date, to_date = view_range(date, view, days)
    events = CalendarEvents.between(from_date, to_date)
    CalendarRenderer.new(width: DISPLAY_WIDTH, height: DISPLAY_HEIGHT, date:, view:, days:, events:)
  end

  def require_token!
    expected = ENV.fetch("CALENDAR_API_TOKEN", "")
    return if expected.empty?

    supplied = request.env["HTTP_AUTHORIZATION"].to_s.delete_prefix("Bearer ")
    halt 401, { error: "Unauthorized" }.to_json unless secure_compare(expected, supplied)
  end

  def integer_param(name, default:, min:, max:)
    value = Integer(params.fetch(name, default))
    raise ArgumentError, "#{name} must be between #{min} and #{max}" unless value.between?(min, max)

    value
  rescue TypeError
    raise ArgumentError, "#{name} must be an integer"
  end

  def parse_date(value)
    Date.iso8601(value)
  rescue Date::Error
    raise ArgumentError, "date must be an ISO-8601 date (YYYY-MM-DD)"
  end

  def view_range(date, view, days)
    case view
    when "day" then [date, date + 1]
    when "agenda" then [date, date + days]
    when "week"
      start_date = date - date.wday
      [start_date, start_date + 7]
    when "month"
      month_start = Date.new(date.year, date.month, 1)
      first_cell = month_start - month_start.wday
      month_end = month_start.next_month - 1
      last_cell = month_end + (6 - month_end.wday)
      [first_cell, last_cell + 1]
    end
  end

  # Avoid timing leaks when a token is configured. No ActiveSupport dependency needed.
  def secure_compare(left, right)
    return false unless left.bytesize == right.bytesize

    left.bytes.zip(right.bytes).reduce(0) { |memo, (a, b)| memo | (a ^ b) }.zero?
  end
end

class CalendarEvents
  Event = Data.define(:title, :starts_at, :ends_at, :all_day, :calendar)

  def self.source_name
    ENV.fetch("CALENDAR_SOURCE", "file")
  end

  def self.between(from_date, to_date)
    case source_name
    when "file" then FileCalendarProvider.new.events_between(from_date, to_date)
    when "google" then GoogleCalendarProvider.new.events_between(from_date, to_date)
    else raise ArgumentError, "CALENDAR_SOURCE must be file or google"
    end
  end
end

class FileCalendarProvider
  def events_between(from_date, to_date)
    path = ENV.fetch("CALENDAR_EVENTS_FILE", "/data/events.json")
    return [] unless File.exist?(path)

    JSON.parse(File.read(path), symbolize_names: true).filter_map do |event|
      starts_at = parse_time(event.fetch(:start))
      ends_at = parse_time(event.fetch(:end, event[:start]))
      all_day = event[:all_day] || date_only?(event[:start])
      next unless overlaps?(starts_at, ends_at, all_day, from_date, to_date)

      CalendarEvents::Event.new(event.fetch(:title), starts_at, ends_at, all_day, event.fetch(:calendar, "Calendar"))
    end
  end

  private

  def parse_time(value)
    Time.iso8601(value)
  rescue ArgumentError
    Time.parse(value)
  end

  def date_only?(value)
    value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
  end

  def overlaps?(starts_at, ends_at, all_day, from_date, to_date)
    return starts_at.to_date < to_date && ends_at.to_date > from_date if all_day

    starts_at < to_date.to_time && ends_at > from_date.to_time
  end
end

class GoogleCalendarProvider
  Calendar = Data.define(:label, :id)
  SCOPE = ["https://www.googleapis.com/auth/calendar.readonly"].freeze

  def events_between(from_date, to_date)
    require "google/apis/calendar_v3"
    require "googleauth"

    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = Google::Auth::UserRefreshCredentials.new(
      client_id: required_env("GOOGLE_CLIENT_ID"),
      client_secret: required_env("GOOGLE_CLIENT_SECRET"),
      refresh_token: required_env("GOOGLE_REFRESH_TOKEN"),
      scope: SCOPE
    )
    calendars.flat_map do |calendar|
      response = service.list_events(
        calendar.id,
        single_events: true,
        order_by: "startTime",
        time_min: from_date.to_time.iso8601,
        time_max: to_date.to_time.iso8601
      )
      response.items.filter_map do |event|
        start_value = event_time(event.start)
        end_value = event_time(event.end)
        CalendarEvents::Event.new(event.summary || "Untitled", start_value, end_value, !event.start.date.nil?, calendar.label)
      end
    end.sort_by(&:starts_at)
  end

  private

  def required_env(name)
    ENV.fetch(name) { raise ArgumentError, "#{name} is required when CALENDAR_SOURCE=google" }
  end

  def event_time(event_date_time)
    return event_date_time.date_time.to_time if event_date_time.date_time

    Time.parse(event_date_time.date.to_s)
  end

  def calendars
    configured = ENV.fetch("GOOGLE_CALENDARS", "").strip
    return [Calendar.new(ENV.fetch("GOOGLE_CALENDAR_LABEL", "Primary"), ENV.fetch("GOOGLE_CALENDAR_ID", "primary"))] if configured.empty?

    configured.split(",").map do |entry|
      label, id = entry.split("=", 2).map(&:strip)
      raise ArgumentError, "GOOGLE_CALENDARS entries must use Label=calendar-id" if label.nil? || label.empty? || id.nil? || id.empty?

      Calendar.new(label, id)
    end
  end
end

# Produces the small view model consumed by views/calendar.erb. Layout and
# visual hierarchy belong in HTML/CSS; Ruby only supplies dates and events.
class CalendarRenderer
  TEMPLATE_PATH = File.expand_path("views/calendar.erb", __dir__)
  STYLESHEET_PATH = File.expand_path("views/calendar.css", __dir__)

  attr_reader :width, :height, :date, :view, :days

  def initialize(width:, height:, date:, view:, days:, events:)
    @width, @height, @date, @view, @days, @events = width, height, date, view, days, events
  end

  def html
    ERB.new(File.read(TEMPLATE_PATH), trim_mode: "-").result_with_hash(renderer: self)
  end

  def stylesheet
    File.read(STYLESHEET_PATH) + <<~CSS

      :root { --month-weeks: #{month_weeks.length}; }
    CSS
  end

  def bmp
    MonochromeRasterizer.new.render(html, width:, height:)
  end

  def bitmap_text(text, size:, bold: false)
    BitmapFont.for_size(size, bold:).svg(text)
  end

  def heading
    case view
    when "agenda" then days == 1 ? "Today" : "Next #{days} Days"
    when "month" then date.strftime("%B %Y")
    when "week" then "Week of #{week_start.strftime("%-d %b %Y")}"
    when "day" then date.strftime("%A, %-d %B %Y")
    end
  end

  def subtitle
    return "#{date.strftime("%-d %b")} – #{(date + days - 1).strftime("%-d %b")}" if view == "agenda"

    "Updated #{Time.now.strftime("%-I:%M %p")}"
  end

  def month_weeks
    start = Date.new(date.year, date.month, 1)
    grid_start = start - start.wday
    finish = start.next_month - 1
    grid_end = finish + (6 - finish.wday)
    (grid_start..grid_end).each_slice(7).map do |week|
      week.map { |day| day_data(day, compact: true) }
    end
  end

  def week_days
    (week_start...(week_start + 7)).map { |day| day_data(day, compact: true) }
  end

  def day_all_day_events
    events_on(date).select(&:all_day)
  end

  def day_timed_events
    events_on(date).reject(&:all_day).sort_by(&:starts_at)
  end

  def agenda_days
    days.times.map do |offset|
      day = date + offset
      { date: day, today: day == Date.today, events: events_on(day).sort_by(&:starts_at) }
    end
  end

  def event_text(event, compact: false)
    return "#{event.title}" if event.all_day || event.starts_at.to_date < date

    "#{event.starts_at.strftime("%-I:%M%P")} #{event.title}"
  end

  def calendar_tag(event)
    tag = event.calendar.to_s.gsub(/[^[:alnum:]]/, "").upcase[0, 3]
    tag.nil? || tag.empty? ? "CAL" : tag
  end

  def event_time(event)
    event.all_day ? "ALL DAY" : event.starts_at.strftime("%-I:%M %p")
  end

  private

  def week_start
    date - date.wday
  end

  def day_data(day, compact:)
    { date: day, current_month: day.month == date.month, events: events_on(day).first(4).map { |event| event_text(event, compact:) } }
  end

  def events_on(day)
    @events.select do |event|
      if event.all_day
        event.starts_at.to_date <= day && event.ends_at.to_date > day
      else
        event.starts_at < (day + 1).to_time && event.ends_at > day.to_time
      end
    end
  end
end

# Chromium is used only on the server. The display continues to receive a
# regular, uncompressed 1-bit BMP3 file.
class MonochromeRasterizer
  # The ERB emits inline SVG pixels from the Terminus BDF source. Chromium
  # screenshots that single document; no text is composited after the fact.
  IMAGE_MAGICK_COMMAND = [ "magick", "png:-",
    "-background", "white",
    "-alpha", "remove",
    "-alpha", "off",
    "-colorspace", "Gray",
    "-threshold", "75%",
    "-type", "bilevel", "-define", "bmp:format=bmp3", "bmp:-"
  ].freeze

  def render(html, width:, height:)
    png = screenshot(html, width:, height:)
    bmp, status = Open3.capture2(*IMAGE_MAGICK_COMMAND, stdin_data: png, binmode: true)
    raise "ImageMagick could not create the calendar BMP" unless status.success?
    raise "ImageMagick returned an unsupported BMP" unless valid_bmp?(bmp, width, height)

    bmp
  end

  private

  def screenshot(html, width:, height:)
    browser = Ferrum::Browser.new(
      window_size: [width, height],
      timeout: 20,
      process_timeout: 20,
      browser_options: {
        "no-sandbox" => nil,
        "disable-dev-shm-usage" => nil,
        "disable-gpu" => nil,
        "disable-font-subpixel-positioning" => nil,
        "disable-lcd-text" => nil,
        "disable-device-discovery-notifications" => nil,
        "force-color-profile" => "srgb"
      }
    )
    browser.go_to("data:text/html;base64,#{Base64.strict_encode64(html)}")
    # Ferrum's window size includes Chrome's headless window chrome. Capture
    # the full document so the CSS-sized 800×480 canvas is never cropped.
    browser.screenshot(full: true, encoding: :binary)
  ensure
    browser&.quit
  end

  def valid_bmp?(bmp, width, height)
    bmp.start_with?("BM") &&
      bmp.byteslice(10, 4).unpack1("V") == 62 &&
      bmp.byteslice(18, 4).unpack1("V") == width &&
      bmp.byteslice(22, 4).unpack1("V") == height &&
      bmp.byteslice(26, 2).unpack1("v") == 1 &&
      bmp.byteslice(28, 2).unpack1("v") == 1 &&
      bmp.byteslice(30, 4).unpack1("V").zero?
  end
end
