class AddWindUnitToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :wind_unit, :string, null: false, default: "mph"
  end
end
