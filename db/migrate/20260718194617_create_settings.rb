class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :temperature_unit, null: false, default: "celsius"

      t.timestamps
    end
  end
end
