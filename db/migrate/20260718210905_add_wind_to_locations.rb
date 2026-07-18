class AddWindToLocations < ActiveRecord::Migration[8.1]
  def change
    # Wind stored in canonical km/h and degrees (0-359); converted for display.
    # Today/tomorrow wind lives in their JSON forecast columns.
    add_column :locations, :current_wind_speed, :decimal, precision: 5, scale: 1
    add_column :locations, :current_wind_direction, :integer
  end
end
