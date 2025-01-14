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
module Statistics
  class UserStatistics < ApplicationRecord
    extend Baw::ActiveRecord::Upsert
    # composite primary key
    self.primary_key = [:user_id, :bucket]

    belongs_to :user

    validates :audio_original_download_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :audio_segment_download_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :audio_download_duration, numericality: { greater_than_or_equal_to: 0 }
    validates :analyzed_audio_duration, numericality: { greater_than_or_equal_to: 0 }
    validates :analyses_completed_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    # Increment the counter that tracks original whole-file downloads
    # @param [User] user - the user to record this statistic for
    # @param [AudioRecording] audio_recording - the recording that was downloaded
    def self.increment_original(user, audio_recording)
      raise 'User must not be nil' if user.nil?

      raise ArgumentError 'audio_recording was nil' if audio_recording.nil?

      upsert_counter({
        user_id: user.id,
        audio_original_download_count: 1,
        audio_download_duration: audio_recording.duration_seconds
      })
    end

    # Increment the counters that tracks media-segment downloads
    # @param [User] user - the recording that was downloaded
    # @param [Numeric] duration - the duration of the segment that was downloaded
    def self.increment_segment(user, duration:)
      raise 'User must not be nil' if user.nil?

      upsert_counter({
        user_id: user.id,
        audio_segment_download_count: 1,
        audio_download_duration: duration
      })
    end

    # Increment the counters that tracks analysis job completions
    # @param [User] user - the user to record this statistic for
    # @param [Numeric] duration - the duration of the segment that was downloaded
    def self.increment_analysis_count(user, duration:)
      raise 'User must not be nil' if user.nil?

      upsert_counter({
        user_id: user.id,
        analyses_completed_count: 1,
        analyzed_audio_duration: duration
      })
    end

    SUM_EXPRESSIONS = {
      audio_original_download_count: arel_table[:audio_original_download_count].cast('bigint').sum,
      audio_segment_download_count: arel_table[:audio_segment_download_count].cast('bigint').sum,
      audio_download_duration: arel_table[:audio_download_duration].cast('decimal').sum,
      analyzed_audio_duration: arel_table[:analyzed_audio_duration].cast('decimal').sum,
      analyses_completed_count: arel_table[:analyses_completed_count].cast('bigint').sum
    }.freeze

    #
    # Returns a hash that sums all buckets, as in, the totals of all stats.
    #
    # @return [Hash<Symbol,Numeric>] A hash of totals for the stats.
    def self.totals
      pick_hash(SUM_EXPRESSIONS)
    end

    #
    #  Returns a hash that sums all buckets for an audio recording,
    #  as in, the totals of all stats for a recording.
    #
    # @param [User,nil] user the user to search for, or nil, for the anonymous user
    #
    # @return [Hash<Symbol,Numeric>] A hash of totals for the stats.
    #
    def self.totals_for(user)
      raise 'User must not be nil' if user.nil?

      pick_hash(SUM_EXPRESSIONS, scope: where(user_id: user.id))
    end
  end
end
