# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_recording_statistics
#
#  analyses_completed_count  :bigint           default(0)
#  bucket                    :tsrange          not null, primary key
#  original_download_count   :bigint           default(0)
#  segment_download_count    :bigint           default(0)
#  segment_download_duration :decimal(, )      default(0.0)
#  audio_recording_id        :bigint           not null, primary key
#
# Indexes
#
#  constraint_baw_audio_recording_statistics_unique        (audio_recording_id,bucket) UNIQUE
#  index_audio_recording_statistics_on_audio_recording_id  (audio_recording_id)
#
# Foreign Keys
#
#  fk_rails_...  (audio_recording_id => audio_recordings.id) ON DELETE => cascade
#
module Statistics
  class AudioRecordingStatistics < ApplicationRecord
    extend Baw::ActiveRecord::Upsert
    # composite primary key
    self.primary_key = [:audio_recording_id, :bucket]

    belongs_to :audio_recording

    validates :original_download_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :segment_download_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :segment_download_duration, numericality: { greater_than_or_equal_to: 0 }
    validates :analyses_completed_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    # Increment the counter that tracks original whole-file downloads
    # @param [AudioRecording] audio_recording - the recording that was downloaded
    def self.increment_original(audio_recording)
      raise ArgumentError 'not an AudioRecording' unless audio_recording.is_a?(AudioRecording)

      upsert_counter(
        { audio_recording_id: audio_recording.id, original_download_count: 1 }
      )
    end

    # Increment the counters that track media-segment downloads
    # @param [AudioRecording] audio_recording - the recording that was downloaded
    # @param [Numeric] duration - the duration of the segment that was downloaded
    def self.increment_segment(audio_recording, duration:)
      raise ArgumentError 'not an AudioRecording' unless audio_recording.is_a?(AudioRecording)

      upsert_counter({
        audio_recording_id: audio_recording.id,
        segment_download_count: 1,
        segment_download_duration: duration
      })
    end

    # Increment the counter that tracks audio analysis completions
    # @param [AudioRecording] audio_recording - the recording that was analyzed
    def self.increment_analysis_count(audio_recording)
      raise ArgumentError 'not an AudioRecording' unless audio_recording.is_a?(AudioRecording)

      upsert_counter({
        audio_recording_id: audio_recording.id,
        analyses_completed_count: 1
      })
    end

    SUM_EXPRESSIONS = {
      original_download_count: arel_table[:original_download_count].cast('bigint').sum,
      segment_download_count: arel_table[:segment_download_count].cast('bigint').sum,
      segment_download_duration: arel_table[:segment_download_duration].cast('decimal').sum,
      analyses_completed_count: arel_table[:analyses_completed_count].cast('bigint').sum
    }.freeze

    #
    # Returns a hash that sums all buckets, as in, the totals of all stats.
    #
    # @return [Hash<Symbol,Numeric>] A hash of totals for the stats.
    #
    def self.totals
      pick_hash(SUM_EXPRESSIONS)
    end

    #
    #  Returns a hash that sums all buckets for an audio recording,
    #  as in, the totals of all stats for a recording.
    #
    # @param [AudioRecording] audio_recording the recording to search for
    #
    # @return [Hash<Symbol,Numeric>] A hash of totals for the stats.
    #
    def self.totals_for(audio_recording)
      pick_hash(SUM_EXPRESSIONS, scope: where(audio_recording_id: audio_recording.id))
    end
  end
end
