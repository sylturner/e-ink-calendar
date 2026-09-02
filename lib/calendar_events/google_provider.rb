# frozen_string_literal: true

require "time"

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
