json.extract! dashboard, :id, :name, :grid_columns, :grid_rows, :created_at, :updated_at
json.url dashboard_url(dashboard, format: :json)
