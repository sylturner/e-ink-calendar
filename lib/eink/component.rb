module Eink
  class Component
    class << self
      attr_reader :component_key, :component_label, :minimum_grid_size, :refresh_interval

      def key(value)
        @component_key = value
      end

      def label(value)
        @component_label = value
      end

      def minimum_size(width:, height:)
        @minimum_grid_size = { width:, height: }
      end

      def refresh_every(value)
        @refresh_interval = value
      end
    end

    def initialize(dashboard_item)
      @dashboard_item = dashboard_item
    end

    attr_reader :dashboard_item

    def cached_panel
      Rails.cache.fetch(cache_key, expires_in: self.class.refresh_interval || 15.minutes) { panel }
    rescue StandardError => error
      Panel.new(
        title: self.class.component_label || dashboard_item.component_key.humanize,
        lines: [ "Unavailable", error.message ],
        footer: "Check configuration"
      )
    end

    def setting(name, default = nil)
      dashboard_item.settings.fetch(name.to_s, dashboard_item.settings.fetch(name.to_sym, default))
    end

    private

    def cache_key
      [ "eink-component", self.class.component_key, dashboard_item.cache_key_with_version ]
    end
  end
end
