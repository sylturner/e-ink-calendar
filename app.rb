# frozen_string_literal: true

require "date"
require "json"
require "sinatra/base"
require_relative "lib/calendar_events"
require_relative "lib/calendar_renderer"

# HTTP boundary for the calendar service. Event sources, document rendering,
# and browser-to-BMP conversion live in their focused lib/ components.
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

  def secure_compare(left, right)
    return false unless left.bytesize == right.bytesize

    left.bytes.zip(right.bytes).reduce(0) { |memo, (a, b)| memo | (a ^ b) }.zero?
  end
end
