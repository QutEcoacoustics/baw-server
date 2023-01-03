# frozen_string_literal: true

# Allow tracking job completions
class RecordAnalysisStats < ActiveRecord::Migration[7.0]
  def change
    change_table :audio_recording_statistics do |t|
      t.bigint :analyses_completed_count, default: 0
    end

    change_table :user_statistics do |t|
      t.bigint :analyses_completed_count, default: 0
    end

    # no column for anonymous user statistics since anonymous users cannot run jobs
  end
end
