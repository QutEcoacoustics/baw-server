class AddTimezoneColumns < ActiveRecord::Migration
  def change
    add_column :users, :tzinfo_tz, :string, null: true, limit: 255
    add_column :users, :rails_tz, :string, null: true, limit: 255

    add_column :sites, :tzinfo_tz, :string, null: true, limit: 255
    add_column :sites, :rails_tz, :string, null: true, limit: 255

    add_column :audio_recordings, :recorded_utc_offset, :string, null: true, limit: 20
  end
end
