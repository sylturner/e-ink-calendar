class CreateDashboards < ActiveRecord::Migration[8.1]
  def change
    create_table :dashboards do |t|
      t.string :name, null: false
      t.integer :grid_columns, null: false, default: 8
      t.integer :grid_rows, null: false, default: 8

      t.timestamps
    end
  end
end
