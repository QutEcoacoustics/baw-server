# frozen_string_literal: true

class CreateVerifications < ActiveRecord::Migration[7.2]
  def change
    create_enum :confirmation, ['correct', 'incorrect', 'unsure', 'skip']

    create_table :verifications do |t|
      t.references :audio_event, null: false, foreign_key: { on_delete: :cascade }
      t.references :tag, null: false, foreign_key: { on_delete: :cascade }
      t.column :creator_id, :integer, null: false
      t.column :updater_id, :integer
      t.column :confirmed, :confirmation, null: false

      t.timestamps
    end

    add_foreign_key :verifications, :users, column: :creator_id
    add_foreign_key :verifications, :users, column: :updater_id

    add_index :verifications, [:audio_event_id, :tag_id, :creator_id], unique: true
  end
end
