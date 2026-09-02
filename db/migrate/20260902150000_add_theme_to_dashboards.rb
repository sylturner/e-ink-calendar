class AddThemeToDashboards < ActiveRecord::Migration[8.1]
  def change
    add_column :dashboards, :theme, :string, null: false, default: "pixelify"
  end
end
