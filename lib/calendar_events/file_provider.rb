# frozen_string_literal: true

require "json"
require "time"

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
