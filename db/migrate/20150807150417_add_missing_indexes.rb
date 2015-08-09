class AddMissingIndexes < ActiveRecord::Migration
  def change
    # from lol_dba: add indexes on foreign keys
    add_index :audio_event_comments, :audio_event_id
    add_index :audio_event_comments, :creator_id
    add_index :audio_event_comments, :updater_id
    add_index :audio_event_comments, :deleter_id
    add_index :audio_event_comments, :flagger_id

    add_index :audio_events, :audio_recording_id
    add_index :audio_events, :creator_id
    add_index :audio_events, :updater_id
    add_index :audio_events, :deleter_id

    add_index :audio_events_tags, :creator_id
    add_index :audio_events_tags, :updater_id

    add_index :audio_recordings, :creator_id
    add_index :audio_recordings, :updater_id
    add_index :audio_recordings, :deleter_id
    add_index :audio_recordings, :uploader_id

    add_index :bookmarks, :audio_recording_id
    add_index :bookmarks, :creator_id
    add_index :bookmarks, :updater_id

    add_index :datasets, :creator_id
    add_index :datasets, :updater_id
    add_index :datasets, :project_id

    add_index :datasets_sites, :site_id
    add_index :datasets_sites, [:dataset_id, :site_id]
    add_index :datasets_sites, :dataset_id

    add_index :jobs, :creator_id
    add_index :jobs, :updater_id
    add_index :jobs, :deleter_id
    add_index :jobs, :script_id
    add_index :jobs, :dataset_id

    add_index :permissions, [:project_id, :user_id]
    add_index :permissions, :project_id
    add_index :permissions, :user_id
    add_index :permissions, :creator_id
    add_index :permissions, :updater_id

    add_index :projects, :creator_id
    add_index :projects, :updater_id
    add_index :projects, :deleter_id

    add_index :projects_sites, :project_id
    add_index :projects_sites, [:project_id, :site_id]
    add_index :projects_sites, :site_id

    add_index :scripts, :creator_id
    add_index :scripts, :updated_by_script_id

    add_index :sites, :creator_id
    add_index :sites, :updater_id
    add_index :sites, :deleter_id

    add_index :tags, :creator_id
    add_index :tags, :updater_id

    # from consistency_fail: add indexes on attributes that are unique
    add_index  :bookmarks, [:name, :creator_id], name: 'bookmarks_name_creator_id_uidx', unique: true, order: {name: :asc}
    add_index  :datasets, [:name, :creator_id], name: 'datasets_name_creator_id_uidx', unique: true, order: {name: :asc}
    add_index  :jobs, :name, name: 'jobs_name_uidx', unique: true, order: {name: :asc}
    add_index  :permissions, [:project_id, :level, :user_id], name: 'permissions_level_user_id_project_id_uidx', unique: true, order: {project_id: :asc, user_id: :asc}
    add_index  :projects, :name, name: 'projects_name_uidx', unique: true, order: {name: :asc}
    add_index  :tags, :text, name: 'tags_text_uidx', unique: true, order: {text: :asc}
    add_index  :scripts, :updated_by_script_id, name: 'scripts_updated_by_script_id_uidx', unique: true
    add_index  :audio_recordings, :uuid, name: 'audio_recordings_uuid_uidx', unique: true

    # already has
    # add_index "audio_events_tags", ["audio_event_id", "tag_id"], name: "index_audio_events_tags_on_audio_event_id_and_tag_id", unique: true, using: :btree
    # add_index "audio_recordings", ["created_at", "updated_at"], name: "audio_recordings_created_updated_at", using: :btree
    # add_index "audio_recordings", ["site_id"], name: "index_audio_recordings_on_site_id", using: :btree
    # add_index "users", ["authentication_token"], name: "index_users_on_authentication_token", unique: true, using: :btree
    # add_index "users", ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true, using: :btree
    # add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
    # add_index "users", ["user_name"], name: "users_user_name_unique", unique: true, using: :btree

    ## TODO: add file_hash unique index the duplicates are resolved.

    # requires modifying the file_hash before this index will succeed
    #execute "UPDATE audio_recordings SET file_hash = null WHERE file_hash = 'SHA256::'"

    #add_index  :audio_recordings, :file_hash, name: 'audio_recordings_file_hash_uidx', unique: true, where: "file_hash <> 'SHA256::'"
  end
end
