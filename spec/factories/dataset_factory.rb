# frozen_string_literal: true

# == Schema Information
#
# Table name: datasets
#
#  id          :integer          not null, primary key
#  description :text
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  creator_id  :integer
#  updater_id  :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (updater_id => users.id)
#
FactoryBot.define do
  factory :dataset do
    sequence(:name) { |n| "gen_dataset_name#{n}" }
    sequence(:description) { |n| "dataset description #{n}" }

    creator
  end
end
