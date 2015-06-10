class AudioRecordingOverlap

  OVERLAP_MESSAGE = 'audio recordings that overlap in the same site (calculated from recording_start and duration_seconds) are not permitted'

  MAX_OVERLAP_COUNT = 10

  class << self

    # Validate audio recording attributes.
    # @param [AudioRecording] audio_recording
    # @return [AudioRecording]
    def validate(audio_recording)
      audio_recording.errors.add(:recorded_date, 'must have a value') if audio_recording.recorded_date.blank?
      audio_recording.errors.add(:recorded_date, 'must be a date time') unless audio_recording.recorded_date.respond_to?(:advance)

      audio_recording.errors.add(:duration_seconds, 'must have a value') if audio_recording.duration_seconds.blank?
      audio_recording.errors.add(:duration_seconds, 'must be a number') unless audio_recording.duration_seconds.is_a?(Numeric)

      audio_recording.errors.add(:site_id, 'must have a value') if audio_recording.site_id.blank?
      audio_recording.errors.add(:site_id, 'must be an integer') unless audio_recording.site_id.is_a?(Fixnum)

      audio_recording
    end

    # Get other audio recordings that overlap.
    # @param [AudioRecording] audio_recording
    # @param [Numeric] max_overlap_seconds maximum amount an audio recording can be trimmed at the end
    # @return [Hash, nil] overlap info, nil if audio_recording has errors
    def get(audio_recording, max_overlap_seconds)
      validate(audio_recording)
      return nil if audio_recording.errors.size > 0

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
      validate(audio_recording)
      return nil if audio_recording.errors.size > 0

      query = overlap_query(audio_recording)

      query.count
    end

    # Do any other audio recordings overlap?
    # @param [AudioRecording] audio_recording
    # @return [Boolean, nil] true if any overlaps, nil if audio_recording has errors
    def any?(audio_recording)
      validate(audio_recording)
      return nil if audio_recording.errors.size > 0

      query = overlap_query(audio_recording)

      query.any?
    end

    # Find and fix overlapping audio recordings.
    # @param [AudioRecording] audio_recording
    # @param [Numeric] max_overlap_seconds maximum amount an audio recording can be trimmed at the end
    # @return [Hash, nil] overlap info, nil if audio_recording has errors
    def fix(audio_recording, max_overlap_seconds)
      validate(audio_recording)
      return nil if audio_recording.errors.size > 0

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

          fix_result = fix_overlap(audio_recording, existing_recording, max_overlap_seconds)

          overlap_info[:fixed] = fix_result[:fixed]
          overlap_info[:errors] = fix_result[:save_errors] if fix_result[:save_errors].size > 0

          result[:overlap][:items].push(overlap_info)
        end

      end

      result
    end

    private

    # Get the overlapping audio recordings in the same site.
    # @param [AudioRecording] audio_recording
    # @return [ActiveRecord::Relation] overlap query
    def overlap_query(audio_recording)

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

      end_b_gt_start_a = end_literal.gt(audio_recording.recorded_date)
      start_b_lt_end_a = audio_recordings_arel[:recorded_date].lt(get_end_date(audio_recording))

      query = AudioRecording
                  .where(site_id: audio_recording.site_id)
                  .where(end_b_gt_start_a)
                  .where(start_b_lt_end_a)

      query = query.where(audio_recordings_arel[:id].not_eq(audio_recording.id)) unless audio_recording.id.blank?

      query
    end

    # Get overlap info for one audio recording.
    # @param [AudioRecording] new_recording
    # @param [AudioRecording] existing_recording
    # @return [Hash] overlap info
    def get_overlap_info(new_recording, existing_recording)

      recorded_b_start = existing_recording.recorded_date
      recording_b_end = existing_recording.recorded_date.dup.advance(seconds: existing_recording.duration_seconds)

      if new_recording.recorded_date < recorded_b_start
        # overlap is at end of new, start of existing
        overlap_amount = get_end_date(new_recording) - recorded_b_start
        overlap_location = 'start of existing, end of new'
      else
        # overlap is at start of new, end of existing
        overlap_amount = recording_b_end - new_recording.recorded_date
        overlap_location = 'start of new, end of existing'
      end

      {
          uuid: existing_recording.uuid,
          id: existing_recording.id,
          recorded_date: existing_recording.recorded_date,
          duration: existing_recording.duration_seconds.to_s,
          end_date: recording_b_end,
          overlap_amount: overlap_amount,
          overlap_location: overlap_location,
          fixed: false
      }
    end

    # Correct overlap and record changes in notes field for both audio recordings.
    # @param [AudioRecording] audio_recording_a
    # @param [AudioRecording] audio_recording_b
    # @param [Numeric] max_overlap_seconds maximum amount an audio recording can be trimmed at the end
    # @return [Boolean] true if fix succeeded, otherwise false
    def fix_overlap(audio_recording_a, audio_recording_b, max_overlap_seconds)
      existing_audio_recording_start = audio_recording_b.recorded_date
      existing_audio_recording_end = get_end_date(audio_recording_b)
      existing_audio_recording_id = audio_recording_b.id
      existing_audio_recording_uuid = audio_recording_b.uuid

      new_audio_recording_start = audio_recording_a.recorded_date
      new_audio_recording_end = get_end_date(audio_recording_a)

      result = {fixed: nil, save_errors: []}

      if existing_audio_recording_start > new_audio_recording_start
        # if overlap is within threshold, modify new_audio_recording
        overlap_amount = new_audio_recording_end - existing_audio_recording_start
        if overlap_amount <= max_overlap_seconds
          audio_recording_a.duration_seconds = audio_recording_a.duration_seconds - overlap_amount
          notes = audio_recording_a.notes.blank? ? '' : audio_recording_a.notes
          audio_recording_a.notes = notes + create_overlap_notes(overlap_amount, existing_audio_recording_uuid)
          result[:fixed] = true
        else
          result[:fixed] = false
        end


      elsif existing_audio_recording_start < new_audio_recording_start
        # if overlap is within threshold, modify existing audio recording
        overlap_amount = existing_audio_recording_end - new_audio_recording_start
        if overlap_amount <= max_overlap_seconds
          existing = AudioRecording.where(id: existing_audio_recording_id).first
          existing.duration_seconds = existing.duration_seconds - overlap_amount
          notes = existing.notes.blank? ? '' : existing.notes
          existing.notes = notes + create_overlap_notes(overlap_amount, audio_recording_a.uuid)

          result[:fixed] = existing.save
          result[:save_errors] = existing.errors if existing.errors.size > 0

        else
          result[:fixed] = false
        end
      end

      result
    end

    # Construct overlap no tes.
    # @param [Numeric] overlap_amount
    # @param [string] other_uuid
    # @return [String]
    def create_overlap_notes(overlap_amount, other_uuid)
      "\n\"duration_adjustment_for_overlap\"=\"Change made #{Time.zone.now.utc.iso8601}: " +
          "overlap of #{overlap_amount} seconds with audio_recording with uuid #{other_uuid}.\""
    end

    # Get the end date for an audio recording.
    # @param [AudioRecording] audio_recording
    # @return [ActiveSupport::TimeWithZone] end date
    def get_end_date(audio_recording)
      audio_recording.recorded_date.dup.advance(seconds: audio_recording.duration_seconds)
    end
  end
end