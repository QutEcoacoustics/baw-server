# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_events
#
#  id                                                                              :integer          not null, primary key
#  channel                                                                         :integer
#  deleted_at                                                                      :datetime
#  end_time_seconds                                                                :decimal(10, 4)
#  high_frequency_hertz                                                            :decimal(10, 4)
#  import_file_index(Index of the row/entry in the file that generated this event) :integer
#  is_reference                                                                    :boolean          default(FALSE), not null
#  low_frequency_hertz                                                             :decimal(10, 4)
#  score(Score or confidence for this event.)                                      :decimal(, )
#  start_time_seconds                                                              :decimal(10, 4)   not null
#  created_at                                                                      :datetime
#  updated_at                                                                      :datetime
#  audio_event_import_file_id                                                      :integer
#  audio_recording_id                                                              :integer          not null
#  creator_id                                                                      :integer          not null
#  deleter_id                                                                      :integer
#  provenance_id(Source of this event)                                             :integer
#  updater_id                                                                      :integer
#
# Indexes
#
#  index_audio_events_on_audio_event_import_file_id  (audio_event_import_file_id)
#  index_audio_events_on_audio_recording_id          (audio_recording_id)
#  index_audio_events_on_creator_id                  (creator_id)
#  index_audio_events_on_deleter_id                  (deleter_id)
#  index_audio_events_on_provenance_id               (provenance_id)
#  index_audio_events_on_updater_id                  (updater_id)
#
# Foreign Keys
#
#  audio_events_audio_recording_id_fk  (audio_recording_id => audio_recordings.id) ON DELETE => cascade
#  audio_events_creator_id_fk          (creator_id => users.id)
#  audio_events_deleter_id_fk          (deleter_id => users.id)
#  audio_events_updater_id_fk          (updater_id => users.id)
#  fk_rails_...                        (audio_event_import_file_id => audio_event_import_files.id) ON DELETE => cascade
#  fk_rails_...                        (provenance_id => provenances.id)
#
FactoryBot.define do
  factory :audio_event do
    start_time_seconds { 5.2 }
    low_frequency_hertz { 400 }
    high_frequency_hertz { 6000 }
    end_time_seconds { 5.8 }
    is_reference { false }

    creator
    audio_recording

    trait :reference do
      is_reference { true }
    end

    trait :with_tags do
      transient do
        audio_event_count { 1 }
      end
      after(:create) do |audio_event, evaluator|
        raise 'Creator was blank' if  evaluator.creator.blank?

        create_list(:tagging, evaluator.audio_event_count, audio_event: audio_event, creator: evaluator.creator)
      end
    end

    trait :with_comments do
      transient do
        audio_event_count { 1 }
      end
      after(:create) do |audio_event, evaluator|
        raise 'Creator was blank' if  evaluator.creator.blank?

        create_list(:comment, evaluator.audio_event_count, audio_event: audio_event, creator: evaluator.creator)
      end
    end

    factory :audio_event_tagging do
      provenance
      score { rand(0...1.0).round(2) }
      end_time_seconds { start_time_seconds + rand(2..4.50).round(2) }
      transient do
        tag { nil }
        confirmations { [] }
        users { [] }
      end

      after(:create) do |audio_event, evaluator|
        create(:tagging, audio_event: audio_event, tag: evaluator.tag, creator: evaluator.creator)

        if evaluator.confirmations.any?
          raise 'users must be >= confirmations' if evaluator.users.size < evaluator.confirmations.size

          evaluator.confirmations.each_with_index do |confirmed, index|
            user = evaluator.users[index]
            create(:verification, audio_event: audio_event, tag: evaluator.tag, creator: user, confirmed:)
          end
        end
      end
    end

    factory :audio_event_with_tags, traits: [:with_tags]
    factory :audio_event_with_comments, traits: [:with_comments]
    factory :audio_event_with_tags_and_comments, traits: [:with_tags, :with_comments]
    factory :audio_event_reference_with_tags, traits: [:with_tags, :reference]
  end
end
