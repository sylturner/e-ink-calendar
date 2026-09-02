module Eink
  class ComponentRegistry
    require_relative "components/calendar_component"

    COMPONENTS = {
      "calendar_today" => Components::CalendarTodayComponent,
      "calendar_tomorrow" => Components::CalendarTomorrowComponent,
      "google_doc" => Components::GoogleDocComponent,
      "weather" => Components::WeatherComponent,
      "quote" => Components::QuoteComponent
    }.freeze

    class << self
      def all
        COMPONENTS.values
      end

      def keys
        COMPONENTS.keys
      end

      def fetch(key)
        COMPONENTS.fetch(key) { Components::PlaceholderComponent }
      end

      def build(dashboard_item)
        fetch(dashboard_item.component_key).new(dashboard_item)
      end
    end
  end
end
