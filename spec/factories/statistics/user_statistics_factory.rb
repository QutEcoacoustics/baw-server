# frozen_string_literal: true

# == Schema Information
#
# Table name: user_statistics
#
#  analyses_completed_count      :bigint           default(0)
#  analyzed_audio_duration       :decimal(, )      default(0.0), not null
#  audio_download_duration       :decimal(, )      default(0.0)
#  audio_original_download_count :bigint           default(0)
#  audio_segment_download_count  :bigint           default(0)
#  bucket                        :tsrange          not null, primary key
#  user_id                       :bigint           not null, primary key
#
# Indexes
#
#  constraint_baw_user_statistics_unique  (user_id,bucket) UNIQUE
#  index_user_statistics_on_user_id       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :user_statistics, class: 'Statistics::UserStatistics' do
    audio_original_download_count { 0 }
    audio_segment_download_count { 0 }
    audio_download_duration { 0 }

    user
  end
end
