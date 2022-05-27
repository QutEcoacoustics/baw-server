# frozen_string_literal: true

# == Schema Information
#
# Table name: anonymous_user_statistics
#
#  audio_download_duration       :decimal(, )      default(0.0)
#  audio_original_download_count :bigint           default(0)
#  audio_segment_download_count  :bigint           default(0)
#  bucket                        :tsrange          not null, primary key
#
# Indexes
#
#  constraint_baw_anonymous_user_statistics_unique  (bucket) UNIQUE
#
FactoryBot.define do
  factory :anonymous_user_statistics, class: 'Statistics::AnonymousUserStatistics' do
    audio_original_download_count { 0 }
    audio_segment_download_count { 0 }
    audio_download_duration { 0 }
  end
end
