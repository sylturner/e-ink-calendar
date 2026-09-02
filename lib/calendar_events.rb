# frozen_string_literal: true

require_relative "calendar_events/file_provider"
require_relative "calendar_events/google_provider"

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
