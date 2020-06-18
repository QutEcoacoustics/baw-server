# frozen_string_literal: true

FactoryBot.define do
  factory :study do
    sequence(:name) { |n| "test study #{n}" }
    creator
    dataset
  end
end
