# frozen_string_literal: true

# The analysis_jobs_items table uses bigint for its primary key, but the
# audio_event_import_files.analysis_jobs_item_id foreign key column was created
# as a 4-byte integer. This causes RangeError when referencing analysis_jobs_items
# with IDs exceeding 2,147,483,647 (the 4-byte integer limit).
#
# See: https://github.com/QutEcoacoustics/baw-server/issues/889
class WidenAnalysisJobsItemIdInAudioEventImportFiles < ActiveRecord::Migration[7.0]
  def up
    # Change the column type from integer (4 bytes) to bigint (8 bytes)
    # to match the analysis_jobs_items.id column type
    change_column :audio_event_import_files, :analysis_jobs_item_id, :bigint
  end

  def down
    change_column :audio_event_import_files, :analysis_jobs_item_id, :integer
  end
end
