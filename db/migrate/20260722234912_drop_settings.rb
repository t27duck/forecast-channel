class DropSettings < ActiveRecord::Migration[8.1]
  # Display preferences now live in the visitor's browser cookies (see Setting /
  # ApplicationController#current_setting), so the singleton settings row is no
  # longer needed.
  def change
    drop_table :settings do |t|
      t.string :temperature_unit, default: "celsius", null: false
      t.string :wind_unit, default: "mph", null: false
      t.timestamps
    end
  end
end
