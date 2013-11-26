require 'faker'
include ActionDispatch::TestProcess

FactoryGirl.define do
  factory :script do
    name {Faker::Name.title}
    notes { {Faker::Lorem.word => Faker::Lorem.paragraph} }
    analysis_identifier {Faker::Lorem.word}
    association :creator, factory: :user
    settings_file { fixture_file_upload(Rails.root.join('public', 'files','script', 'settings_file.txt'), 'text/plain') }
    data_file { fixture_file_upload(Rails.root.join('public', 'files','script', 'settings_file.txt'), 'text/plain') }
  end
end