class AddSlugToLocations < ActiveRecord::Migration[8.1]
  # Backfilled through the model so the slug (and its collision suffix) is
  # derived in exactly one place. Safe to lean on the model here: a fresh
  # database loads db/schema.rb rather than replaying this, so it only ever runs
  # against the few hundred rows of an existing one.
  def up
    add_column :locations, :slug, :string
    Location.reset_column_information
    Location.find_each(&:save!)

    change_column_null :locations, :slug, false
    add_index :locations, :slug, unique: true
  end

  def down
    remove_column :locations, :slug
  end
end
