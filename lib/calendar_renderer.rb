# frozen_string_literal: true

require "date"
require "erb"
require_relative "bitmap_font"
require_relative "monochrome_rasterizer"

# Produces the small view model consumed by the ERB templates. Layout and
# visual hierarchy belong in HTML/CSS; Ruby only supplies dates and events.
class CalendarRenderer
  ROOT = File.expand_path("..", __dir__)
  TEMPLATE_PATH = File.join(ROOT, "views/calendar.erb")
  PARTIALS_PATH = File.join(ROOT, "views/calendar")
  STYLESHEET_PATH = File.join(ROOT, "views/calendar.css")

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

  def view_partial
    partial_name = view.to_s
    raise ArgumentError, "unknown calendar view partial: #{partial_name}" unless %w[agenda day week month].include?(partial_name)

    ERB.new(File.read(File.join(PARTIALS_PATH, "#{partial_name}.erb")), trim_mode: "-").result_with_hash(renderer: self)
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
    return event.title.to_s if event.all_day || event.starts_at.to_date < date

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
