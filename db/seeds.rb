dashboard = Dashboard.default

items = [
  { component_key: "calendar_today", settings: { "calendar_ids" => [ "primary" ], "max_events" => 6 }, grid_x: 0, grid_y: 0, grid_width: 2, grid_height: 6 },
  { component_key: "calendar_tomorrow", settings: { "calendar_ids" => [ "primary" ], "max_events" => 6 }, grid_x: 2, grid_y: 0, grid_width: 2, grid_height: 6 },
  { component_key: "google_doc", settings: { "title" => "NOTES" }, grid_x: 4, grid_y: 0, grid_width: 4, grid_height: 6 },
  { component_key: "weather", settings: {}, grid_x: 0, grid_y: 6, grid_width: 2, grid_height: 2 },
  { component_key: "quote", settings: {}, grid_x: 2, grid_y: 6, grid_width: 6, grid_height: 2 }
]

items.each do |attributes|
  item = dashboard.dashboard_items.find_or_initialize_by(component_key: attributes.fetch(:component_key))
  item.assign_attributes(attributes.merge(enabled: true))
  item.save!
end
