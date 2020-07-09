# frozen_string_literal: true

FactoryBot.define do
  factory :progress_event do
    activity { 'viewed' }

    dataset_item
    creator
  end
end
