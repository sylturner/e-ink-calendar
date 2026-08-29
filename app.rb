# frozen_string_literal: true

require "cgi"
require "date"
require "json"
require "open3"
require "sinatra/base"
require "time"

class CalendarApp < Sinatra::Base
  configure do
    set :show_exceptions, false
    set :raise_errors, false
  end

  get "/healthz" do
    content_type :json
    { status: "ok", source: CalendarEvents.source_name }.to_json
  end

  get "/calendar.png" do
    render_calendar("png")
  end

  get "/calendar.bmp" do
    render_calendar("bmp")
  end

  error ArgumentError do
    halt 400, { error: env["sinatra.error"].message }.to_json
  end

  error StandardError do
    warn env["sinatra.error"].full_message
    halt 500, { error: "Could not render calendar" }.to_json
  end

  private

  def render_calendar(format)
    require_token!
    width = integer_param("width", default: 800, min: 200, max: 2400)
    height = integer_param("height", default: 480, min: 200, max: 1600)
    day = parse_date(params.fetch("date", Date.today.iso8601))
    view = params.fetch("view", "agenda")
    raise ArgumentError, "view must be agenda, month, week, or day" unless %w[agenda month week day].include?(view)
    days = view == "agenda" ? integer_param("days", default: 5, min: 5, max: 7) : nil

    from_date, to_date = view_range(day, view, days)
    events = CalendarEvents.between(from_date, to_date)
    image = CalendarRenderer.new(width:, height:, date: day, view:, days:, events:).public_send(format)

    content_type format == "png" ? "image/png" : "image/bmp"
    headers(
      "Cache-Control" => "no-store",
      "Content-Disposition" => "inline; filename=calendar.#{format}",
      "X-Image-Bit-Depth" => "1"
    )
    image
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
    # A YYYY-MM-DD is an all-day event in the service timezone.
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

class CalendarRenderer
  FONT_PRESETS = {
    "mono" => "'DejaVu Sans Mono', monospace",
    "sans" => "'DejaVu Sans', sans-serif",
    "serif" => "'DejaVu Serif', serif"
  }.freeze
  PADDING = 12

  def initialize(width:, height:, date:, view:, days:, events:)
    @width, @height, @date, @view, @days, @events = width, height, date, view, days, events
  end

  def png
    bilevel_png
  end

  def bmp
    output, error, status = Open3.capture3(
      ENV.fetch("IMAGEMAGICK_COMMAND", "magick"), "png:-", "-define", "bmp:format=bmp3", "-compress", "none", "BMP3:-", stdin_data: bilevel_png
    )
    raise "ImageMagick failed to encode BMP: #{error.strip}" unless status.success?

    output
  end

  private

  def bilevel_png
    raster, error, status = Open3.capture3("rsvg-convert", "--format=png", stdin_data: svg)
    raise "SVG rasterizer failed: #{error.strip}" unless status.success?

    output, error, status = Open3.capture3(
      ENV.fetch("IMAGEMAGICK_COMMAND", "magick"), "png:-", "-colorspace", "Gray", "-threshold", "65%", "-type", "bilevel", "-define", "png:bit-depth=1", "png:-", stdin_data: raster
    )
    raise "ImageMagick failed to render calendar: #{error.strip}" unless status.success?

    output
  end

  def svg
    case @view
    when "agenda" then agenda_svg
    when "month" then month_svg
    when "week" then week_svg
    when "day" then day_svg
    end
  end

  def month_svg
    month_start = Date.new(@date.year, @date.month, 1)
    grid_start = month_start - month_start.wday
    month_end = month_start.next_month - 1
    grid_end = month_end + (6 - month_end.wday)
    weeks = ((grid_end - grid_start + 1) / 7).to_i
    title_height = 42
    weekday_height = 18
    cell_width = (@width - (PADDING * 2)).fdiv(7)
    cell_height = (@height - title_height - weekday_height - PADDING).fdiv(weeks)
    event_size = [[cell_height * 0.18, 8].max, 13].min
    max_events = [[((cell_height - 25) / (event_size + 2)).floor, 1].max, 4].min
    lines = title_lines(@date.strftime("%B %Y"))

    7.times do |index|
      x = PADDING + (index * cell_width)
      lines << text(x + (cell_width / 2), title_height + 13, Date::ABBR_DAYNAMES[index], "weekday", anchor: "middle")
    end

    (0...(weeks * 7)).each do |index|
      date = grid_start + index
      column = index % 7
      row = index / 7
      x = PADDING + (column * cell_width)
      y = title_height + weekday_height + (row * cell_height)
      lines << rect(x, y, cell_width, cell_height, "cell")
      day_class = date.month == @date.month ? "day-number" : "outside-day"
      lines << text(x + 4, y + 14, date.day, day_class)
      event_lines_for(date, max_events, compact: true).each_with_index do |event_line, event_index|
        lines << text(x + 4, y + 27 + (event_index * (event_size + 2)), truncate(event_line, event_capacity(cell_width, event_size)), "event")
      end
    end

    document(lines, <<~CSS)
      .title { font-size: #{title_size}px; font-weight: bold; }
      .updated { font-size: #{small_size}px; }
      .weekday { font-size: #{small_size}px; font-weight: bold; }
      .cell { fill: none; stroke: black; stroke-width: 1; }
      .day-number { font-size: #{small_size}px; font-weight: bold; }
      .outside-day { font-size: #{small_size}px; }
      .event { font-size: #{event_size}px; }
    CSS
  end

  def week_svg
    start_date = @date - @date.wday
    title_height = 42
    header_height = 25
    column_width = (@width - (PADDING * 2)).fdiv(7)
    column_height = @height - title_height - PADDING
    event_size = [[column_width * 0.11, 8].max, 13].min
    max_events = [[((column_height - header_height - 6) / (event_size + 3)).floor, 1].max, 12].min
    lines = title_lines("Week of #{start_date.strftime("%-d %b %Y")}")

    7.times do |index|
      date = start_date + index
      x = PADDING + (index * column_width)
      y = title_height
      lines << rect(x, y, column_width, column_height, "cell")
      lines << text(x + 4, y + 16, date.strftime("%a %-d"), "day-heading")
      event_lines_for(date, max_events, compact: true).each_with_index do |event_line, event_index|
        lines << text(x + 4, y + header_height + (event_index * (event_size + 3)), truncate(event_line, event_capacity(column_width, event_size)), "event")
      end
    end

    document(lines, <<~CSS)
      .title { font-size: #{title_size}px; font-weight: bold; }
      .updated { font-size: #{small_size}px; }
      .cell { fill: none; stroke: black; stroke-width: 1; }
      .day-heading { font-size: #{small_size}px; font-weight: bold; }
      .event { font-size: #{event_size}px; }
    CSS
  end

  def day_svg
    all_day = events_on(@date).select(&:all_day)
    timed = events_on(@date).reject(&:all_day).sort_by(&:starts_at)
    title_height = 48
    time_width = [@width * 0.16, 78].max
    event_size = [[@height * 0.042, 12].max, 19].min
    row_height = event_size + 10
    lines = title_lines(@date.strftime("%A, %-d %B %Y"))
    y = title_height

    all_day.each do |event|
      lines << rect(PADDING, y, @width - (PADDING * 2), row_height, "all-day-box")
      lines << text(PADDING + 6, y + event_size + 1, event_label(event, @date), "event")
      y += row_height
    end

    timed.each do |event|
      break if y + row_height > @height - PADDING

      lines << line(PADDING, y, @width - PADDING, y, "rule")
      lines << text(PADDING + 4, y + event_size + 2, event.starts_at.strftime("%-I:%M %p"), "time")
      lines << text(PADDING + time_width, y + event_size + 2, truncate(event_label(event, @date), event_capacity(@width - time_width - PADDING, event_size)), "event")
      y += row_height
    end
    lines << text(PADDING + time_width, y + event_size + 2, "No events", "empty") if all_day.empty? && timed.empty?

    document(lines, <<~CSS)
      .title { font-size: #{title_size}px; font-weight: bold; }
      .updated { font-size: #{small_size}px; }
      .all-day-box { fill: black; stroke: black; }
      .all-day-box + text { fill: white; }
      .rule { stroke: black; stroke-width: 1; }
      .time { font-size: #{small_size}px; font-weight: bold; }
      .event { font-size: #{event_size}px; }
      .empty { font-size: #{event_size}px; }
    CSS
  end

  def agenda_svg
    row_height = (@height - 48 - PADDING).fdiv(@days)
    event_size = [[row_height * 0.28, 14].max, 20].min
    event_line_height = event_size + 4
    date_width = [@width * 0.16, 122].max
    max_events = [[(row_height / event_line_height).floor, 1].max, 3].min
    end_date = @date + @days - 1
    title = @days == 1 ? @date.strftime("Today") : "Next #{@days} Days"
    subtitle = "#{@date.strftime("%-d %b")} – #{end_date.strftime("%-d %b")}" 
    lines = [
      text(PADDING, title_size + 4, title, "title"),
      text(@width - PADDING, title_size + 4, subtitle, "range", anchor: "end")
    ]

    @days.times do |index|
      date = @date + index
      y = 48 + (index * row_height)
      lines << line(PADDING, y, @width - PADDING, y, "rule")
      lines << text(PADDING + 3, y + small_size + 6, date.strftime("%a").upcase, "agenda-day")
      lines << text(PADDING + 3, y + (small_size * 2) + 10, date.strftime("%-d %b"), "agenda-date")
      lines << rect(PADDING + 2, y + row_height - 13, 43, 10, "today-badge") if date == Date.today
      lines << text(PADDING + 5, y + row_height - 5, "TODAY", "today-text") if date == Date.today

      day_events = events_on(date)
      next if day_events.empty?

      agenda_events_for(date, max_events).each_with_index do |event, event_index|
        event_y = y + event_size + 4 + (event_index * event_line_height)
        lines.concat(agenda_event_lines(PADDING + date_width, event_y, event, date, @width - PADDING - date_width, event_size))
      end
    end
    lines << line(PADDING, @height - PADDING, @width - PADDING, @height - PADDING, "rule")

    document(lines, <<~CSS)
      .title { font-size: #{title_size}px; font-weight: bold; }
      .range { font-size: #{small_size + 1}px; font-weight: bold; }
      .rule { stroke: black; stroke-width: 1; }
      .agenda-day { font-size: #{small_size + 1}px; font-weight: bold; }
      .agenda-date { font-size: #{small_size + 1}px; }
      .today-badge { fill: black; }
      .today-text { font-size: 7px; font-weight: bold; fill: white; }
      .calendar-tag { fill: black; }
      .tag-text { fill: white; font-size: #{[event_size * 0.62, 8].max}px; font-weight: bold; }
      .event { font-size: #{event_size}px; font-weight: bold; }
    CSS
  end

  def title_lines(title)
    [
      text(PADDING, title_size + 4, title, "title"),
      text(@width - PADDING, title_size + 4, "Updated #{Time.now.strftime("%-I:%M %p")}", "updated", anchor: "end")
    ]
  end

  def events_on(date)
    @events.select { |event| event_on_date?(event, date) }
  end

  def event_lines_for(date, limit, compact: false)
    lines = events_on(date).map { |event| event_label(event, date, compact:) }
    return lines if lines.length <= limit

    lines.take(limit - 1) + ["+#{lines.length - limit + 1} more"]
  end

  def agenda_events_for(date, limit)
    events = events_on(date)
    return events if events.length <= limit

    events.take(limit)
  end

  def agenda_event_lines(x, y, event, date, available_width, event_size)
    tag = calendar_tag(event)
    tag_width = [tag.length * event_size * 0.5 + 9, 23].max
    title_x = x + tag_width + 6
    prefix = event.all_day || event.starts_at.to_date < date ? "" : "#{event.starts_at.strftime("%-I:%M%P")} "
    title = truncate("#{prefix}#{event.title}", event_capacity(available_width - tag_width - 6, event_size))
    [
      rect(x, y - event_size + 3, tag_width, event_size + 2, "calendar-tag"),
      text(x + (tag_width / 2), y, tag, "tag-text", anchor: "middle"),
      text(title_x, y, title, "event")
    ]
  end

  def event_label(event, date, compact: false)
    prefix = compact ? "#{calendar_tag(event)} " : "[#{event.calendar}] "
    return "#{prefix}#{event.title}" if event.all_day || event.starts_at.to_date < date

    "#{prefix}#{event.starts_at.strftime("%-I:%M%P")} #{event.title}"
  end

  def calendar_tag(event)
    event.calendar.to_s.gsub(/[^[:alnum:]]/, "").upcase[0, 3].then { |tag| tag.empty? ? "CAL" : tag }
  end

  def event_on_date?(event, date)
    return event.starts_at.to_date <= date && event.ends_at.to_date > date if event.all_day

    event.starts_at < (date + 1).to_time && event.ends_at > date.to_time
  end

  def truncate(text, length)
    text.length > length ? "#{text[0, length - 1]}…" : text
  end

  def document(lines, styles)
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="#{@width}" height="#{@height}" viewBox="0 0 #{@width} #{@height}">
        <rect width="100%" height="100%" fill="white" />
        <style>
          text { font-family: #{font_family}; fill: black; }
          #{styles}
        </style>
        #{lines.join("\n")}
      </svg>
    SVG
  end

  def text(x, y, content, klass, anchor: nil)
    anchor_attribute = anchor ? %( text-anchor="#{anchor}") : ""
    %(<text x="#{x.round(2)}" y="#{y.round(2)}" class="#{klass}"#{anchor_attribute}>#{escape(content)}</text>)
  end

  def rect(x, y, width, height, klass)
    %(<rect x="#{x.round(2)}" y="#{y.round(2)}" width="#{width.round(2)}" height="#{height.round(2)}" class="#{klass}" />)
  end

  def line(x1, y1, x2, y2, klass)
    %(<line x1="#{x1.round(2)}" y1="#{y1.round(2)}" x2="#{x2.round(2)}" y2="#{y2.round(2)}" class="#{klass}" />)
  end

  def title_size
    [[@width / 28, 20].max, 36].min
  end

  # Only use bundled, known-safe font stacks. The SVG is generated per request,
  # so accepting an arbitrary environment value here would allow CSS injection.
  def font_family
    FONT_PRESETS.fetch(ENV.fetch("CALENDAR_FONT", "mono").downcase, FONT_PRESETS.fetch("mono"))
  end

  def small_size
    [[@width / 62, 9].max, 15].min
  end

  def event_capacity(width, font_size)
    [(width / (font_size * 0.56)).floor, 8].max
  end

  def escape(text)
    CGI.escapeHTML(text.to_s)
  end
end
