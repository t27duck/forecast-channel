class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      # Identity / geocoding
      t.string :name, null: false
      t.decimal :latitude, precision: 9, scale: 6, null: false
      t.decimal :longitude, precision: 9, scale: 6, null: false
      t.string :country
      t.string :country_code
      t.string :admin1
      t.string :timezone
      t.decimal :elevation, precision: 8, scale: 2
      t.integer :population
      t.integer :open_meteo_id

      # Current conditions
      t.decimal :current_temperature, precision: 5, scale: 2
      t.integer :current_condition_code
      t.string :current_condition_label
      t.decimal :uv_index, precision: 4, scale: 1
      t.string :uv_label
      t.datetime :weather_refreshed_at

      # Forecast breakdowns (populated by the later weather-refresh task)
      t.json :today_forecast, default: {}, null: false
      t.json :tomorrow_forecast, default: {}, null: false
      t.json :hourly_windows, default: [], null: false
      t.json :five_day_forecast, default: [], null: false

      t.timestamps
    end

    add_index :locations, [ :latitude, :longitude ]
  end
end
