# frozen_string_literal: true

# Add table for tracking harvests
class AddHarvestsTable < ActiveRecord::Migration[7.0]
  def change
    # add allow harvesting switch to projects
    change_table :projects do |t|
      t.boolean :allow_audio_upload, default: false
    end

    # create a harvests table
    create_table :harvests do |t|
      # streaming harvests process files as they arrive
      t.boolean :streaming

      #         :streaming
      # :new -> :uploading -> :metadata_extraction -> :metadata_review -> :processing -> :review -> :complete
      t.string :status

      # credentials will exist in :uploading, :processing, and :review stages
      # and they will be deleted on :complete
      t.string :upload_user
      t.string :upload_password

      t.integer :project_id, null: false

      # client: folder tree view maps to points
      # which would map paths to point ids
      t.jsonb :mappings
      # [
      #  { path: "/creek", site_id: 1, recursive: true}
      #  { path: "/creek/A", site_id: 1, recursive: true}
      # ]

      t.integer :creator_id
      t.integer :updater_id
      t.timestamps
    end

    # link harvest items to harvests
    change_table :harvest_items do |t|
      t.integer :harvest_id, null: true
    end

    add_foreign_key :harvests, :projects
    add_foreign_key :harvest_items, :harvests
    add_foreign_key :harvests, :users, column: :creator_id
    add_foreign_key :harvests, :users, column: :updater_id
  end
end
