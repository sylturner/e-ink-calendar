json.extract! dashboard_item, :id, :dashboard_id, :component_key, :settings, :grid_x, :grid_y, :grid_width, :grid_height, :enabled, :created_at, :updated_at
json.url dashboard_item_url(dashboard_item, format: :json)
