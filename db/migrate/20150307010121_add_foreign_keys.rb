class AddForeignKeys < ActiveRecord::Migration
  def up
    add_foreign_key "audio_event_comments", "audio_events", name: "audio_event_comments_audio_event_id_fk"
    add_foreign_key "audio_event_comments", "users", column: "creator_id", name: "audio_event_comments_creator_id_fk"
    add_foreign_key "audio_event_comments", "users", column: "deleter_id", name: "audio_event_comments_deleter_id_fk"
    add_foreign_key "audio_event_comments", "users", column: "flagger_id", name: "audio_event_comments_flagger_id_fk"
    add_foreign_key "audio_event_comments", "users", column: "updater_id", name: "audio_event_comments_updater_id_fk"

    add_foreign_key "audio_events", "users", column: "creator_id", name: "audio_events_creator_id_fk"
    add_foreign_key "audio_events", "users", column: "deleter_id", name: "audio_events_deleter_id_fk"
    add_foreign_key "audio_events", "users", column: "updater_id", name: "audio_events_updater_id_fk"

    add_foreign_key "audio_events_tags", "users", column: "creator_id", name: "audio_events_tags_creator_id_fk"
    add_foreign_key "audio_events_tags", "tags", name: "audio_events_tags_tag_id_fk"
    add_foreign_key "audio_events_tags", "users", column: "updater_id", name: "audio_events_tags_updater_id_fk"

    add_foreign_key "audio_recordings", "users", column: "creator_id", name: "audio_recordings_creator_id_fk"
    add_foreign_key "audio_recordings", "users", column: "deleter_id", name: "audio_recordings_deleter_id_fk"
    add_foreign_key "audio_recordings", "sites", name: "audio_recordings_site_id_fk"
    add_foreign_key "audio_recordings", "users", column: "updater_id", name: "audio_recordings_updater_id_fk"
    add_foreign_key "audio_recordings", "users", column: "uploader_id", name: "audio_recordings_uploader_id_fk"

    add_foreign_key "bookmarks", "audio_recordings", name: "bookmarks_audio_recording_id_fk"
    add_foreign_key "bookmarks", "users", column: "creator_id", name: "bookmarks_creator_id_fk"
    add_foreign_key "bookmarks", "users", column: "updater_id", name: "bookmarks_updater_id_fk"

    add_foreign_key "datasets", "users", column: "creator_id", name: "datasets_creator_id_fk"
    add_foreign_key "datasets", "projects", name: "datasets_project_id_fk"
    add_foreign_key "datasets", "users", column: "updater_id", name: "datasets_updater_id_fk"

    add_foreign_key "datasets_sites", "datasets", name: "datasets_sites_dataset_id_fk"
    add_foreign_key "datasets_sites", "sites", name: "datasets_sites_site_id_fk"

    add_foreign_key "jobs", "users", column: "creator_id", name: "jobs_creator_id_fk"
    add_foreign_key "jobs", "datasets", name: "jobs_dataset_id_fk"
    add_foreign_key "jobs", "users", column: "deleter_id", name: "jobs_deleter_id_fk"
    add_foreign_key "jobs", "scripts", name: "jobs_script_id_fk"
    add_foreign_key "jobs", "users", column: "updater_id", name: "jobs_updater_id_fk"

    add_foreign_key "permissions", "projects", name: "permissions_project_id_fk"
    add_foreign_key "permissions", "users", column: "updater_id", name: "permissions_updater_id_fk"

    add_foreign_key "projects", "users", column: "creator_id", name: "projects_creator_id_fk"
    add_foreign_key "projects", "users", column: "deleter_id", name: "projects_deleter_id_fk"
    add_foreign_key "projects", "users", column: "updater_id", name: "projects_updater_id_fk"

    add_foreign_key "projects_sites", "projects", name: "projects_sites_project_id_fk"
    add_foreign_key "projects_sites", "sites", name: "projects_sites_site_id_fk"

    add_foreign_key "scripts", "users", column: "creator_id", name: "scripts_creator_id_fk"
    add_foreign_key "scripts", "scripts", column: "updated_by_script_id", name: "scripts_updated_by_script_id_fk"

    add_foreign_key "sites", "users", column: "creator_id", name: "sites_creator_id_fk"
    add_foreign_key "sites", "users", column: "deleter_id", name: "sites_deleter_id_fk"
    add_foreign_key "sites", "users", column: "updater_id", name: "sites_updater_id_fk"

    add_foreign_key "tags", "users", column: "creator_id", name: "tags_creator_id_fk"
    add_foreign_key "tags", "users", column: "updater_id", name: "tags_updater_id_fk"

    # these require changes before they will succeed :/

    # delete audio events where no audio recording matches
    execute "DELETE FROM audio_events
WHERE id IN (
  SELECT ae.id
  FROM audio_events ae
  LEFT OUTER JOIN audio_recordings ar on ae.audio_recording_id = ar.id
  WHERE ar.id is null
)"

    add_foreign_key "audio_events", "audio_recordings", name: "audio_events_audio_recording_id_fk"

    # delete the audio_event_tags where the audio event doesn't exist.

    execute "DELETE FROM audio_events_tags
WHERE audio_event_id IN (
  SELECT aet.audio_event_id
  FROM audio_events_tags aet
  LEFT OUTER JOIN audio_events ae on aet.audio_event_id = ae.id
  WHERE ae.id is null
)"

    add_foreign_key "audio_events_tags", "audio_events", name: "audio_events_tags_audio_event_id_fk"

    # delete the permissions where the user or creator do not exist
    execute "DELETE FROM permissions
WHERE user_id IN (
  SELECT p.user_id
  FROM permissions p
  LEFT OUTER JOIN users u on p.user_id = u.id
  WHERE u.id is null
)"

    add_foreign_key "permissions", "users", name: "permissions_user_id_fk"

    execute "DELETE FROM permissions
WHERE creator_id IN (
  SELECT p.creator_id
  FROM permissions p
  LEFT OUTER JOIN users u on p.creator_id = u.id
  WHERE u.id is null
)"

    add_foreign_key "permissions", "users", column: "creator_id", name: "permissions_creator_id_fk"
  end

  def down
    fail ActiveRecord::IrreversibleMigration
  end
end
