module DashboardItemsHelper
  def component_options
    Eink::ComponentRegistry.all.map do |component|
      [ component.component_label, component.component_key ]
    end
  end
end
