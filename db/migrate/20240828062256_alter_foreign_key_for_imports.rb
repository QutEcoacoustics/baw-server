# frozen_string_literal: true

require_relative '../migration_helpers'

# Alter foreign keys for imports to cascade on delete
class AlterForeignKeyForImports < ActiveRecord::Migration[7.0]
  include MigrationsHelpers

  def change
    [
      get_foreign_key(:audio_event_comments, :audio_event_id),
      get_foreign_key(:audio_event_import_files, :audio_event_import_id),
      get_foreign_key(:audio_events, :audio_event_import_file_id),
      get_foreign_key(:audio_events_tags, :audio_event_id)
    ] => fks

    fks.each do |fk|
      alter_foreign_key_cascade(fk, on_delete_cascade: true)
    end
  end
end
