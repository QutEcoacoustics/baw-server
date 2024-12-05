# frozen_string_literal: true

# Adds provenance reference to scripts and updates the version column to be an integer
class ScriptUpdateAndProvenance < ActiveRecord::Migration[7.0]
  def change
    change_column_comment :scripts, :analysis_identifier,
      from: nil,
      to: 'a unique identifier for this script in the analysis system, used in directory names. [-a-z0-0_]'

    reversible do |dir|
      dir.up do
        change_column :scripts, :version, :integer, default: 1, null: false,
          comment: 'Version of this script - not the version of program the script runs!'
      end

      dir.down do
        change_column :scripts, :version, :decimal, precision: 4, scale: 2, default: 0.1, null: false
      end
    end

    change_table :scripts do |t|
      t.references :provenance, null: true, foreign_key: true, type: :integer
      t.string :event_import_glob, null: true,
        comment: 'Glob pattern to match result files that should be imported as audio events'
    end
  end
end
