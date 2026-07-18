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

ActiveRecord::Schema[8.1].define(version: 2026_07_18_190739) do
  create_table "locations", force: :cascade do |t|
    t.string "admin1"
    t.string "country"
    t.string "country_code"
    t.datetime "created_at", null: false
    t.integer "current_condition_code"
    t.string "current_condition_label"
    t.decimal "current_temperature", precision: 5, scale: 2
    t.decimal "elevation", precision: 8, scale: 2
    t.json "five_day_forecast", default: [], null: false
    t.json "hourly_windows", default: [], null: false
    t.decimal "latitude", precision: 9, scale: 6, null: false
    t.decimal "longitude", precision: 9, scale: 6, null: false
    t.string "name", null: false
    t.integer "open_meteo_id"
    t.integer "population"
    t.string "timezone"
    t.json "today_forecast", default: {}, null: false
    t.json "tomorrow_forecast", default: {}, null: false
    t.datetime "updated_at", null: false
    t.decimal "uv_index", precision: 4, scale: 1
    t.string "uv_label"
    t.datetime "weather_refreshed_at"
    t.index ["latitude", "longitude"], name: "index_locations_on_latitude_and_longitude"
  end
end
