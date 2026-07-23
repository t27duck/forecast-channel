class CreateSounds < ActiveRecord::Migration[8.1]
  def change
    create_table :sounds do |t|
      # Which slot the uploaded track fills (see Sound::KINDS); one track each.
      t.string :kind, null: false

      t.timestamps
    end

    add_index :sounds, :kind, unique: true
  end
end
