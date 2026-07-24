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

ActiveRecord::Schema[8.1].define(version: 2026_07_24_231500) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "locations", force: :cascade do |t|
    t.string "admin1"
    t.integer "air_quality_index"
    t.string "air_quality_label"
    t.decimal "air_quality_pm2_5", precision: 6, scale: 1
    t.string "country"
    t.string "country_code"
    t.datetime "created_at", null: false
    t.decimal "current_apparent_temperature", precision: 5, scale: 2
    t.integer "current_condition_code"
    t.string "current_condition_label"
    t.integer "current_humidity"
    t.integer "current_precipitation_probability"
    t.decimal "current_temperature", precision: 5, scale: 2
    t.integer "current_wind_direction"
    t.decimal "current_wind_speed", precision: 5, scale: 1
    t.decimal "elevation", precision: 8, scale: 2
    t.json "five_day_forecast", default: [], null: false
    t.json "hourly_windows", default: [], null: false
    t.datetime "last_viewed_at"
    t.decimal "latitude", precision: 9, scale: 6, null: false
    t.decimal "longitude", precision: 9, scale: 6, null: false
    t.string "name", null: false
    t.integer "open_meteo_id"
    t.integer "population"
    t.string "slug", null: false
    t.string "timezone"
    t.json "today_forecast", default: {}, null: false
    t.json "tomorrow_forecast", default: {}, null: false
    t.datetime "updated_at", null: false
    t.decimal "uv_index", precision: 4, scale: 1
    t.string "uv_label"
    t.datetime "weather_refreshed_at"
    t.index ["last_viewed_at"], name: "index_locations_on_last_viewed_at"
    t.index ["latitude", "longitude"], name: "index_locations_on_latitude_and_longitude"
    t.index ["slug"], name: "index_locations_on_slug", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sounds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_sounds_on_kind", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "sessions", "users"
end
