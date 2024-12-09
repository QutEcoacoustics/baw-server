# frozen_string_literal: true

# == Schema Information
#
# Table name: responses
#
#  id              :integer          not null, primary key
#  data            :text
#  created_at      :datetime
#  creator_id      :integer
#  dataset_item_id :integer
#  question_id     :integer
#  study_id        :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (dataset_item_id => dataset_items.id) ON DELETE => cascade
#  fk_rails_...  (question_id => questions.id)
#  fk_rails_...  (study_id => studies.id)
#
FactoryBot.define do
  factory :response do
    data_json = <<~JSON
      {"labels_present": [1,2]}
    JSON
    data { data_json }
    creator
    study
    dataset_item
  end
end
