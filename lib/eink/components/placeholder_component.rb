module Eink
  module Components
    class PlaceholderComponent < Component
      label "Component"
      refresh_every 1.minute

      def panel
        Panel.new(
          title: dashboard_item.component_key.humanize,
          lines: [ "This component has not been installed yet." ],
          footer: "Configure it in Edit dashboard"
        )
      end
    end
  end
end
