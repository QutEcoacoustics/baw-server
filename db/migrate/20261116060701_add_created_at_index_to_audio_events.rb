# frozen_string_literal: true

# Audio events are listed newest first by default, so every paged request sorts by created_at.
# Without an index, Postgres has to sort every matching event just to return the first page.
# The audio_events table is large, so build the index concurrently to avoid locking out writes.
class AddCreatedAtIndexToAudioEvents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :audio_events, :created_at, algorithm: :concurrently
  end
end
