class CreateResponses < ActiveRecord::Migration
  def change
    create_table :responses do |t|

      t.integer :creator_id
      t.integer :dataset_item_id
      t.integer :question_id
      t.integer :study_id

      t.text :data
      t.timestamps null: false
    end

    add_foreign_key :responses, :dataset_items
    add_foreign_key :responses, :questions
    add_foreign_key :responses, :studies
    add_foreign_key :responses, :users, column: :creator_id
  end
end
