# frozen_string_literal: true

class AudioRecordingOverlap
  OVERLAP_MESSAGE = 'audio recordings that overlap in the same site (calculated from recording_start and duration_seconds) are not permitted'

  MAX_OVERLAP_COUNT = 10

  class << self
    # Get other audio recordings that overlap.
    # @param [AudioRecording] audio_recording
    # @param [Numeric] max_overlap_seconds maximum amount an audio recording can be trimmed at the end
    # @return [Hash, nil] overlap info, nil if audio_recording has errors
    def get(audio_recording, max_overlap_seconds)
      query = overlap_query(audio_recording)
      result_count = query.count

      result = {
        id: audio_recording.id,
        recorded_date: audio_recording.recorded_date,
        end_date: get_end_date(audio_recording),
        duration_sec: audio_recording.duration_seconds,
        site_id: audio_recording.site_id,
        overlap: {
          max_overlap_sec: max_overlap_seconds,
          message: OVERLAP_MESSAGE,
          count: result_count,
          items: [],
          maximum_count: MAX_OVERLAP_COUNT,
          too_many: false
        }
      }

      if result_count > MAX_OVERLAP_COUNT
        result[:overlap][:too_many] = true
      else
        query.each do |existing_recording|
          overlap_info = get_overlap_info(audio_recording, existing_recording)
          result[:overlap][:items].push(overlap_info)
        end
      end

      result
    end

    # Number of other audio recordings that overlap.
    # @param [AudioRecording] audio_recording
    # @return [Integer, nil] overlap count, nil if audio_recording has errors
    def count(audio_recording)
      overlap_query(audio_recording).count
    end

    # Do any other audio recordings overlap?
    # @param [AudioRecording] audio_recording
    # @return [Boolean, nil] true if any overlaps, nil if audio_recording has errors
    def any?(audio_recording)
      overlap_query(audio_recording).any?
    end

    # Find and fix overlapping audio recordings.
    # @param [AudioRecording] audio_recording
    # @param [Numeric] max_overlap_seconds maximum amount an audio recording can be trimmed at the end
    # @return [Hash, nil] overlap info, nil if audio_recording has errors
    def fix(audio_recording, max_overlap_seconds, save: true)
      query = overlap_query(audio_recording)
      result_count = query.count

      result = {
        id: audio_recording.id,
        recorded_date: audio_recording.recorded_date,
        end_date: get_end_date(audio_recording),
        duration_sec: audio_recording.duration_seconds,
        site_id: audio_recording.site_id,
        max_overlap_sec: max_overlap_seconds,
        overlap: {
          message: OVERLAP_MESSAGE,
          count: result_count,
          items: [],
          maximum_count: MAX_OVERLAP_COUNT,
          too_many: false
        }
      }

      if result_count > MAX_OVERLAP_COUNT
        result[:overlap][:too_many] = true
      else

        query.each do |existing_recording|
          overlap_info = get_overlap_info(audio_recording, existing_recording)

          fix_result = fix_overlap(audio_recording, existing_recording, overlap_info, max_overlap_seconds, save:)

          overlap_info[:fixed] = fix_result[:fixed]
          overlap_info[:errors] = fix_result[:save_errors] unless fix_result[:save_errors].empty?

          result[:overlap][:items].push(overlap_info)
        end

      end

      result
    end

    # Get the overlapping audio recordings in the same site.
    # @param [AudioRecording] audio_recording
    # @return [ActiveRecord::Relation] overlap query
    def overlap_query(audio_recording)
      overlap_query_simple(
        id: audio_recording.id,
        recorded_date: audio_recording.recorded_date,
        duration_seconds: audio_recording.duration_seconds,
        site_id: audio_recording.site_id
      )
    end

    def overlap_query_simple(id:, recorded_date:, duration_seconds:, site_id:)
      # audio recordings overlap if:
      #  - end B > start A and
      #  - start B < end A
      # where A is reference, B is comparison

      # recordings are overlapping if:
      # do not have the same id,
      # do have same site
      # start is before .recorded_date.advance(seconds: self.duration_seconds)
      # and end is before self.recorded_date
      # self.id may be nil if audio_recording is not saved to database yet

      audio_recordings_arel = Arel::Table.new(:audio_recordings)
      end_literal = Arel::Nodes::SqlLiteral.new('recorded_date + CAST(duration_seconds || \' seconds\' as interval)')

      end_b_gt_start_a = end_literal.gt(recorded_date)
      start_b_lt_end_a = audio_recordings_arel[:recorded_date].lt(get_end_date_simple(recorded_date, duration_seconds))

      query = AudioRecording
              .where(site_id:)
              .where(end_b_gt_start_a)
              .where(start_b_lt_end_a)

      query = query.where(audio_recordings_arel[:id].not_eq(id)) unless id.blank?

      query
    end

    # Get overlap info for one existing audio recording.
    # @param [AudioRecording] new_recording
    # @param [AudioRecording] existing_recording
    # @return [Hash] overlap info
    def get_overlap_info(new_recording, existing_recording)
      recording_new_start = new_recording.recorded_date
      recording_new_end = get_end_date(new_recording)

      recording_existing_start = existing_recording.recorded_date
      recording_existing_end = get_end_date(existing_recording)

      can_fix = false

      if recording_new_start < recording_existing_start && recording_new_end < recording_existing_end
        # overlap is at start of existing, end of new
        overlap_amount = recording_new_end - recording_existing_start
        overlap_location = 'start of existing, end of new'
        can_fix = true
      elsif recording_new_start > recording_existing_start && recording_new_end > recording_existing_end
        # overlap is at start of new, end of existing
        overlap_amount = recording_existing_end - recording_new_start
        overlap_location = 'start of new, end of existing'
        can_fix = true
      else
        min_end = [recording_new_end, recording_existing_end].min
        max_start = [recording_new_start, recording_existing_start].max

        overlap_amount = if max_start > min_end
                           0.0
                         else
                           min_end - max_start
                         end

        overlap_location = 'no overlap or recordings overlap completely'
        can_fix = false
      end

      {
        uuid: existing_recording.uuid,
        id: existing_recording.id,
        recorded_date: recording_existing_start,
        duration: existing_recording.duration_seconds,
        end_date: recording_existing_end,
        overlap_amount:,
        overlap_location:,
        can_fix:,
        fixed: false
      }
    end

    # Correct overlap and record changes in notes field for both audio recordings.
    # @param [AudioRecording] a
    # @param [AudioRecording] b
    # @param [Hash] overlap_info
    # @param [Numeric] max_overlap_seconds maximum amount an audio recording can be trimmed at the end
    # @return [Boolean] true if fix succeeded, otherwise false
    def fix_overlap(a, b, overlap_info, max_overlap_seconds, save: true)
      # don't assume that either audio_recording is saved
      # so, can't use id.
      # assume both recordings have been validated.

      # decide which audio recording to modify
      if a.recorded_date > b.recorded_date
        earlier = b
        later = a
      else
        earlier = a
        later = b
      end

      # calculate information needed later
      earlier_end = get_end_date(earlier)
      later_start = later.recorded_date
      overlap_amount = earlier_end - later_start

      result = { fixed: nil, save_errors: [] }

      if overlap_amount <= max_overlap_seconds && overlap_info[:can_fix]
        # correct the overlap by modifying the duration of the earlier recording
        result = modify_duration(earlier, later, overlap_amount, save:)
      end

      result
    end

    def modify_duration(modified, other, overlap_amount, save:)
      new_duration = modified.duration_seconds - overlap_amount
      current_duration = modified.duration_seconds
      modified.duration_seconds = new_duration

      # make sure notes has the duration_adjustment_for_overlap array
      modified.notes = {} if modified.notes.blank?
      unless modified.notes.include?('duration_adjustment_for_overlap')
        modified.notes['duration_adjustment_for_overlap'] = []
      end

      # add new overlap info to the duration_adjustment_for_overlap array
      new_overlap_info = create_overlap_notes(overlap_amount, current_duration, new_duration, other.uuid)
      modified.notes['duration_adjustment_for_overlap'].push(new_overlap_info)

      # provide access to model save result and errors
      save_result = save ? modified.save : modified.validate
      save_errors = modified.errors.dup

      {
        fixed: save_result,
        save_errors:
      }
    end

    # Construct overlap notes.
    # @param [Numeric] overlap_amount
    # @param [String] other_uuid
    # @return [Hash]
    def create_overlap_notes(overlap_amount, current_duration, new_duration, other_uuid)
      {
        changed_at: Time.zone.now.utc.iso8601,
        overlap_amount:,
        old_duration: current_duration,
        new_duration:,
        other_uuid:
      }
    end

    # Get the end date for an audio recording.
    # @param [AudioRecording] audio_recording
    # @return [ActiveSupport::TimeWithZone] end date
    def get_end_date(audio_recording)
      audio_recording.recorded_date.dup.advance(seconds: audio_recording.duration_seconds)
    end

    # Get the end date for an audio recording.
    # @param [AudioRecording] audio_recording
    # @return [ActiveSupport::TimeWithZone] end date
    def get_end_date_simple(recorded_date, duration_seconds)
      unless recorded_date.is_a?(Time)
        raise ArgumentError,
          "recorded_date class is #{recorded_date.class} instad of Time"
      end

      recorded_date + duration_seconds
    end
  end
end
