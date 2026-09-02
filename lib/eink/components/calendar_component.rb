module Eink
  module Components
    class CalendarComponent < Component
      minimum_size width: 2, height: 3
      refresh_every 15.minutes

      def panel
        date = target_date
        events = GoogleClient.new.events(
          calendar_ids: calendar_ids,
          starts_at: date.beginning_of_day,
          ends_at: date.end_of_day
        )

        lines = events.first(max_events).map { |event| "#{time_label(event)}  #{event.fetch(:summary)}" }
        lines = [ "No events" ] if lines.empty?

        Panel.new(title: title, lines: lines, footer: date.strftime("%A, %b %-d"))
      end

      private

      def calendar_ids
        ids = Array(setting(:calendar_ids)).compact_blank
        ids = ENV.fetch("GOOGLE_CALENDAR_IDS", "primary").split(",").map(&:strip) if ids.empty?
        ids
      end

      def max_events
        setting(:max_events, 6).to_i.clamp(1, 12)
      end

      def time_label(event)
        return "ALL DAY" if event.fetch(:all_day)

        event.fetch(:starts_at).strftime("%-I:%M%P")
      end
    end

    class CalendarTodayComponent < CalendarComponent
      key "calendar_today"
      label "Today's calendar"

      private

      def target_date = Date.current
      def title = "TODAY"
    end

    class CalendarTomorrowComponent < CalendarComponent
      key "calendar_tomorrow"
      label "Tomorrow's calendar"

      private

      def target_date = Date.current.tomorrow
      def title = "TOMORROW"
    end
  end
end
