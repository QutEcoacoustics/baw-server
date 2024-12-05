# frozen_string_literal: true

# == Schema Information
#
# Table name: progress_events
#
#  id              :integer          not null, primary key
#  activity        :string
#  created_at      :datetime
#  creator_id      :integer
#  dataset_item_id :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (dataset_item_id => dataset_items.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :progress_event do
    activity { 'viewed' }

    dataset_item
    creator
  end
end
