require 'faker'

FactoryGirl.define do

  after(:build) { |object| Rails.logger.debug "Built #{object.inspect}" }
  after(:create) { |object| Rails.logger.debug "Created #{object.inspect}" }

  # TODO: these factories should be cleaned up. factory_for_factory is unneccessary once we have factories of varying completeness or use FactoryGirl.create options

  factory :tag do |f|
    is_taxanomic false
    sequence(:text) { |n| Faker::Lorem.word + n.to_s }
    type_of_tag [:general, :common_name, :species_name, :looks_like, :sounds_like].sample
    retired false
    association :creator, factory: :user
  end

  factory :tagging, class: Tagging do
    association :creator, factory: :user
    tag
    audio_event
  end

  factory :audio_event_for_audio_recording, class: AudioEvent do
    start_time_seconds Random.rand(100) + 10 # making sure start is over 10 so it doesn't interfere with tests against specific times
    end_time_seconds Random.rand(100) + 200
    low_frequency_hertz Random.rand(100)
    high_frequency_hertz Random.rand(100) + 4000
    is_reference false

    association :creator, factory: :user
    after(:create) do |audio_event|
      FactoryGirl.create(:tagging, audio_event: audio_event)
    end
  end

  factory :audio_recording_for_site, class: AudioRecording do
    bit_rate_bps Random.rand(64) * 100
    channels Random.rand(2) + 1
    data_length_bytes Random.rand(64)
    duration_seconds Random.rand(600)
    file_hash 'SHA256::fbb815630fa3b432003f3c11aea4b8da566c20d05601f2adedfb9407991f87ac'
    media_type 'audio/mp3'
    recorded_date '2012-03-26 07:06:59'
    sample_rate_hertz Random.rand(441) * 100
    status 'ready'
    notes { {Faker::Lorem.word => Faker::Lorem.paragraph} }
    association :uploader, factory: :user
    association :creator, factory: :harvester
    after(:create) do |audio_recording|
      FactoryGirl.create(:audio_event_for_audio_recording, audio_recording: audio_recording, creator: audio_recording.uploader)
    end
  end

  factory :site_for_project, class: Site do
    name { Faker::Name.title }
    latitude Random.rand(-90.0..90.0)
    longitude Random.rand(-180.0..180.0)
    notes { {Faker::Lorem.word => Faker::Lorem.paragraph} }
    association :creator, factory: :user
    after(:create) do |site|
      FactoryGirl.create(:audio_recording_for_site, site: site)
    end
  end

  factory :dataset_for_project, class: Dataset do
    name { Faker::Name.title }
    description { Faker::Lorem.paragraph }
    association :creator, factory: :user
  end

  factory :project_for_permission, class: Project do
    name { Faker::Name.title }
    description { Faker::Lorem.sentences(2) }
    notes { {Faker::Lorem.word => Faker::Lorem.paragraph} }
    sequence(:urn) { |n| "urn:project:ecosounds.org/project/#{n}" }

    association :creator, factory: :user
    association :owner, factory: :user

    after(:create) do |project, evaluator|
      FactoryGirl.create(:site_for_project, projects: [project])
      FactoryGirl.create(:dataset_for_project, project: project)
    end
  end

  factory :read_permission, class: Permission do
    association :creator, factory: :user
    association :user, factory: :user # this is the user for which the permission is checked
    association :project, factory: :project_for_permission
    level { 'reader' }
  end
  factory :write_permission, class: Permission do
    association :creator, factory: :user
    association :user, factory: :user # this is the user for which the permission is checked
    association :project, factory: :project_for_permission
    level { 'writer' }
  end
end