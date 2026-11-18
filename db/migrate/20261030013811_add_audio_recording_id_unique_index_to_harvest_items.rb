# frozen_string_literal: true

# A harvest item produces at most one audio recording, and an audio recording
# comes from at most one harvest item. Enforce this existing 0..1 : 1 relationship.
# NULLs are not considered duplicates, so harvest items without a recording are still allowed.
#
# We didn't traditionally enforce this because we weren't sure of the harvest design.
# This currently hold true in production, but is causing us metadata issues
# because rails doesn't really think it is a 1:1 relationship.
# If it turns out this is is a mistake it's easey enough to undo the index later if we need this
# to actually be a 1:many index.
class AddAudioRecordingIdUniqueIndexToHarvestItems < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :harvest_items, :audio_recording_id, unique: true, algorithm: :concurrently
  end
end
