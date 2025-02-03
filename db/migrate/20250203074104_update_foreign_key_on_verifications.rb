# frozen_string_literal: true

class UpdateForeignKeyOnVerifications < ActiveRecord::Migration[7.2]
  def change
    remove_foreign_key :verifications, :audio_events
    add_foreign_key :verifications, :audio_events, on_delete: :cascade
  end
end
