class CreateAudioRecordings < ActiveRecord::Migration[4.2]
  def change
    create_table :audio_recordings do |t|

      t.string   'uuid',              :limit => 36, :null => false
      t.integer  'uploader_id',                     :null => false
      t.datetime 'recorded_date',                   :null => false
      t.integer  'site_id',                         :null => false
      t.decimal  'duration_seconds',                :null => false
      t.integer  'sample_rate_hertz'
      t.integer  'channels'
      t.integer  'bit_rate_bps'
      t.string   'media_type',                      :null => false
      t.integer  'data_length_bytes',               :null => false
      t.string   'file_hash',        :limit => 524, :null => false
      t.string   'status',                          :default => 'new'
      t.text     'notes'
      t.integer  'creator_id'
      t.integer  'updater_id'
      t.integer  'deleter_id'
      t.timestamps null: true
      t.datetime 'deleted_at'

    end
  end
end
