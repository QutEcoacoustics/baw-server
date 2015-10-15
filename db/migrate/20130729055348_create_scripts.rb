class CreateScripts < ActiveRecord::Migration
  def change
    create_table :scripts do |t|
      t.string :name, null: false, limit: 255
      t.string :description, limit: 255
      t.text :notes
      t.attachment :settings_file
      t.attachment :data_file
      t.string :analysis_identifier, null: false, limit: 255
      t.decimal :version, null: false, precision: 4, scale: 2, default: 0.1
      t.boolean :verified, default: false
      t.integer :updated_by_script_id
      t.integer :creator_id, null: false
      t.datetime :created_at
    end
  end
end
