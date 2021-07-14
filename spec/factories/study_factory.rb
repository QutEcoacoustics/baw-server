# frozen_string_literal: true

# == Schema Information
#
# Table name: studies
#
#  id         :integer          not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  creator_id :integer
#  dataset_id :integer
#  updater_id :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (dataset_id => datasets.id)
#  fk_rails_...  (updater_id => users.id)
#
FactoryBot.define do
  factory :study do
    sequence(:name) { |n| "test study #{n}" }
    creator
    dataset
  end
end
