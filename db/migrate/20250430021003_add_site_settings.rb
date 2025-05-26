# frozen_string_literal: true

# Add site settings table.
class AddSiteSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :site_settings do |t|
      t.string :name, null: false
      t.string :value, null: false

      t.timestamps
    end

    add_index :site_settings, :name, unique: true
  end
end
