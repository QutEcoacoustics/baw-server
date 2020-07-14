class CreateQuestions < ActiveRecord::Migration[4.2]
  def change
    create_table :questions do |t|
      t.integer :creator_id
      t.integer :updater_id
      t.text :text
      t.text :data
      t.timestamps null: false
    end

    create_table :questions_studies, id: false do |t|
      t.integer :question_id, :null => false
      t.integer :study_id, :null => false
    end

    add_foreign_key :questions, :users, column: :creator_id
    add_foreign_key :questions, :users, column: :updater_id
    add_foreign_key :questions_studies, :questions
    add_foreign_key :questions_studies, :studies

  end
end
