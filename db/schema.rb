# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_02_150000) do
  create_table "dashboard_items", force: :cascade do |t|
    t.string "component_key", null: false
    t.datetime "created_at", null: false
    t.integer "dashboard_id", null: false
    t.boolean "enabled", default: true, null: false
    t.integer "grid_height", null: false
    t.integer "grid_width", null: false
    t.integer "grid_x", null: false
    t.integer "grid_y", null: false
    t.json "settings", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["dashboard_id", "grid_y", "grid_x"], name: "index_dashboard_items_on_dashboard_id_and_grid_y_and_grid_x"
    t.index ["dashboard_id"], name: "index_dashboard_items_on_dashboard_id"
  end

  create_table "dashboards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "grid_columns", default: 8, null: false
    t.integer "grid_rows", default: 8, null: false
    t.string "name", null: false
    t.string "theme", default: "pixelify", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "dashboard_items", "dashboards"
end
