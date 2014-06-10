FactoryGirl.define do

  factory :project do
    sequence(:name) { |n| "project#{n}" }
    sequence(:description) { |n| "project description #{n}" }
    sequence(:urn) { |n| "urn:project:#{n}" }
    sequence(:notes) { |n|  "note number #{n}" }

    association :creator

    trait :image do
      image_file { fixture_file_upload(Rails.root.join('public', 'images', 'user', 'user_spanhalf.png'), 'image/png') }
    end
  end
end