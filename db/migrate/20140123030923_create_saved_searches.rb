class CreateSavedSearches < ActiveRecord::Migration
  def up

    # datasets table becomes saved_searches table
    rename_table :datasets, :saved_searches

    # remove and add columns
    change_table :saved_searches do |t|
      t.remove :dataset_result_file_name
      t.remove :dataset_result_content_type
      t.remove :dataset_result_file_size
      t.remove :dataset_result_updated_at
      t.string :auto_generated_identifer
      t.integer :deleter_id
      t.datetime :deleted_at
    end

    # change linking table
    rename_column :datasets_sites, :dataset_id, :saved_search_id
    rename_table :datasets_sites, :saved_searches_sites

    create_table :datasets do |t|
      t.string :processing_status, null: false
      t.decimal :total_duration_seconds, precision: 10, scale: 4
      t.integer :audio_recording_count
      t.datetime :earliest_datetime
      t.time :earliest_time_of_day
      t.datetime :latest_datetime
      t.time :latest_time_of_day
      t.integer :saved_search_id, null: false
      t.integer :creator_id, null: false
      t.integer :updater_id
      t.integer :deleter_id
      t.datetime :deleted_at
      t.timestamps # created_at, updated_at
    end
  end

  def down
    drop_table :datasets

    # change linking table
    rename_table :saved_searches_sites, :datasets_sites
    rename_column :datasets_sites, :saved_search_id, :dataset_id

    # remove and add columns
    change_table :saved_searches do |t|
      t.string :dataset_result_file_name
      t.string :dataset_result_content_type
      t.integer :dataset_result_file_size
      t.datetime :dataset_result_updated_at
      t.remove :auto_generated_identifer
      t.remove :deleter_id
      t.remove :deleted_at
    end

    # saved_searches becomes datasets table
    rename_table :saved_searches, :datasets

  end
end