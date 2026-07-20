class AddAirQualityAndConditionsToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :air_quality_index, :integer
    add_column :locations, :air_quality_label, :string
    add_column :locations, :air_quality_pm2_5, :decimal, precision: 6, scale: 1
    add_column :locations, :current_humidity, :integer
    add_column :locations, :current_precipitation_probability, :integer
  end
end
