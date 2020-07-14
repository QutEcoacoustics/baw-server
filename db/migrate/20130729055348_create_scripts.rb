class CreateScripts < ActiveRecord::Migration[4.2]
  def change
    create_table :scripts do |t|
      t.string :name                 , null: false
      t.string :description
      t.text :notes
      t.attachment :settings_file
      t.attachment :data_file
      t.string :analysis_identifier  , null: false
      t.decimal :version             , null: false, precision: 4, scale: 2, default: 0.1
      t.boolean :verified            , default: false
      t.integer :updated_by_script_id
      t.integer :creator_id          , null: false
      t.datetime :created_at
    end
  end
end
