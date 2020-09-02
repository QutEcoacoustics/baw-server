# frozen_string_literal: true

FactoryBot.define do
  factory :region do
    sequence(:name) { |n| "region name #{n}" }
    sequence(:description) { |n| "site **description** #{n}" }
    sequence(:notes) { |n| { "region_note_#{n}" => n } }

    project

    creator
  end
end
