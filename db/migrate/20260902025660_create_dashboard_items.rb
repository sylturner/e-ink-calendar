class CreateDashboardItems < ActiveRecord::Migration[8.1]
  def change
    create_table :dashboard_items do |t|
      t.references :dashboard, null: false, foreign_key: true
      t.string :component_key, null: false
      t.json :settings, null: false, default: {}
      t.integer :grid_x, null: false
      t.integer :grid_y, null: false
      t.integer :grid_width, null: false
      t.integer :grid_height, null: false
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :dashboard_items, [ :dashboard_id, :grid_y, :grid_x ]
  end
end
