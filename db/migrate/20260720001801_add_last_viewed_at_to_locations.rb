class AddLastViewedAtToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :last_viewed_at, :datetime
    add_index :locations, :last_viewed_at
  end
end
