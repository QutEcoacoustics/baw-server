class CreateTagGroups < ActiveRecord::Migration
  def change

    create_table :tag_groups do |t|
      t.string :group_identifier, null: false, limit: 255
      t.datetime :created_at, null: false
      t.integer :creator_id, null: false

      t.references :tag, foreign_key: true, index: true, null: false
    end

    add_index(:tag_groups, [:tag_id, :group_identifier], unique: true, name: 'tag_groups_uidx')

  end
end
