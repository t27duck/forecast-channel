class AddApparentTemperatureToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :current_apparent_temperature, :decimal, precision: 5, scale: 2
  end
end
