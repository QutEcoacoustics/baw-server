# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # All validations that the harvester will check
      module Validations
        module_function

        def simple_validations
          [
            FileExists,
            IsAfile,
            FileEmpty,
            TargetType

          ]
        end

        def after_extract_metadata_validations
          [
            RecordedDate,
            AmbiguousDateTime,
            FutureDates,
            NoDuration,
            MinimumDuration,
            ChannelCount,
            SampleRate,
            BitRate,
            MediaType,
            NotADuplicate,
            NotADuplicateForHarvest,
            HasAnUploader,
            BelongsToASite,
            NotOverlapping,
            NotOverlappingForHarvest
          ]
        end

        def apply_corrections(harvest_item); end

        # Run through all validations. Stops when a non-fixable error is found.
        # @param harvest_item [HarvestItem]
        # @return [Array<ValidationResult>]
        def validate(validations, harvest_item)
          results = []
          catch(:halt) do
            validations.each do |validation|
              result = validation.instance.validate(harvest_item)
              BawWorkers::Config.logger_worker.debug('validation run', name: validation.code, status: result&.status)

              results << result

              # no point in continuing if it is impossible to resovle
              throw :halt if result&.status == ValidationResult::STATUS_NOT_FIXABLE
            end
          end

          results
        end

        class FileExists < Validation
          code :does_not_exist

          def validate(harvest_item)
            path = harvest_item.absolute_path
            return if path.exist?

            not_fixable("File #{path} does not exist")
          end
        end

        class IsAfile < Validation
          code :not_a_file

          def validate(harvest_item)
            not_fixable('is not a file') unless harvest_item.absolute_path.file?
          end
        end

        class FileEmpty < Validation
          code :file_empty

          def validate(harvest_item)
            size = harvest_item.absolute_path.size
            return not_fixable("File has no content (#{size} bytes)") unless size.positive?
          end
        end

        class TargetType < Validation
          code :invalid_extension

          def validate(harvest_item)
            path = harvest_item.absolute_path

            valid_audio_formats = Settings.available_formats.audio
            return if BawWorkers::Config.file_info.valid_ext?(path, valid_audio_formats)

            not_fixable("has invalid extension #{extension}")
          end
        end

        class RecordedDate < Validation
          code :missing_date

          def validate(harvest_item)
            recorded_date = harvest_item.info.file_info[:recorded_date_local]
            return if recorded_date.present?

            fixable('We could not find a recorded date for this file')
          end
        end

        class AmbiguousDateTime < Validation
          code :ambiguous_date_time

          def validate(harvest_item)
            utc_offset = harvest_item.info.file_info[:utc_offset]
            recorded_date = harvest_item.info.file_info[:recorded_date]

            return unless recorded_date.nil? || utc_offset.blank?

            fixable('Only a local date/time was found, supply an UTC offset')
          end
        end

        class FutureDates < Validation
          code :future_date

          def validate(harvest_item)
            recorded_date = harvest_item.info.file_info[:recorded_date]
            return unless recorded_date.present? && recorded_date <= Time.now

            fixable('This file has a recorded date in the future')
          end
        end

        class NoDuration < Validation
          code :no_duration

          def validate(harvest_item)
            duration = harvest_item.info.file_info[:duration_seconds]
            return unless duration.blank?

            not_fixable('Could not find a duration for this file')
          end
        end

        class MinimumDuration < Validation
          code :too_short

          def validate(harvest_item)
            duration = harvest_item.info.file_info[:duration_seconds]
            return if duration >= Settings.audio_recording_min_duration_sec

            not_fixable("This file is too short (#{duration} seconds)")
          end
        end

        class ChannelCount < Validation
          code :channel_count

          def validate(harvest_item)
            channels = harvest_item.info.file_info[:channels]
            # channels should be an integer >= 1
            return if channels.present? && channels >= 1 && channels.is_a?(Integer)

            not_fixable("This file has too few channels (#{channels})")
          end
        end

        class SampleRate < Validation
          code :sample_rate

          def validate(harvest_item)
            sample_rate = harvest_item.info.file_info[:sample_rate_hertz]
            return if sample_rate.present? && sample_rate.is_a?(Numeric) && sample_rate.positive?

            not_fixable("The sample rate is invalid (#{sample_rate})")
          end
        end

        class BitRate < Validation
          code :bit_rate

          def validate(harvest_item)
            bit_rate = harvest_item.info.file_info[:bit_rate_bps]
            return if bit_rate.present? && bit_rate.positive? && bit_rate.is_a?(Integer)

            not_fixable("The bit rate is invalid (#{bit_rate})")
          end
        end

        class MediaType < Validation
          code :media_type

          def validate(harvest_item)
            media_type = harvest_item.info.file_info[:media_type]
            return if media_type.present? && media_type.is_a?(String)

            not_fixable("The media type is missing (#{media_type})")
          end
        end

        class NotADuplicate < Validation
          code :duplicate_file

          def validate(harvest_item)
            file_hash = harvest_item.info.file_info[:file_hash]
            not_fixable('File hash is missing') if file_hash.blank?

            # check if the file hash is already in the database
            # if it is, then we can't add it again
            duplicates = AudioRecording.where(file_hash:).limit(10).pluck(:id)
            return if duplicates.empty?

            not_fixable("File duplicate of audio recordings: #{duplicates.join(', ')}. Hash: #{file_hash}")
          end
        end

        class NotADuplicateForHarvest < Validation
          code :duplicate_file_in_harvest

          def validate(harvest_item)
            file_hash = harvest_item.info.file_info[:file_hash]
            not_fixable('File hash is missing') if file_hash.blank?

            # check if the file hash is already in the database for this harvest
            # if it is, then we can't add it again
            duplicates_in_this_job = HarvestItem
                                     .where(harvest_id: harvest_item.harvest_id)
                                     .where("info->'file_info'->>'file_hash' = '#{file_hash}'")
                                     .limit(10)

            return if duplicates_in_this_job.empty?

            duplicate_msg = duplicates_in_this_job.map(&:path).join(', ')
            msg = "File duplicate of harvest items: #{duplicate_msg}. Hash: #{file_hash}"

            not_fixable(msg)
          end
        end
      end

      class HasAnUploader < Validation
        code :missing_uploader

        def validate(harvest_item)
          uploader_id = harvest_item.info.file_info[:uploader_id]
          uploader = User.find_by(id: uploader_id)
          fixable('File hash is missing') if uploader_id.blank? || uploader.nil?
        end
      end

      class UploaderAllowed < Validation
        code :not_allowed_to_upload

        def validate(harvest_item)
          uploader_id = harvest_item.info.file_info[:uploader_id]
          uploader = User.find_by(id: uploader_id)

          can_upload = Ability.new(uploader).can?(:harvest_audio, harvest_item.harvest)
          not_fixable('User is not allowed to upload audio recordings') unless can_upload
        end
      end

      class BelongsToASite < Validation
        code :no_site_id

        def validate(harvest_item)
          site_id = harvest_item.info.file_info[:site_id]
          fixable('No site id found. Update the harvest mappings.') if site_id.blank? || Site.find(site_id).nil?
        end
      end

      class NotOverlapping < Validation
        code :overlapping_files

        def validate(harvest_item)
          recording = fake_recording(harvest_item)

          # If we don't have enough information, then we can't check for overlap.
          # Prior validations should have caught this so we'll skip this
          # check until next time
          return unless recording

          result = AudioRecordingOverlap.get(fake_recording, max_overlap)

          return if result[:overlap][:items].empty?

          msg = <<~MSG
            The file #{harvest_item.rel_path} overlaps with the following audio recordings: #{result[:overlap][:items].join(', ')}}}
          MSG

          fixable = result[:overlap][:items].all? { |item| item[:can_fix] }
          # we're not reurning a fixable validation here because it's not something
          # user can fix. We will fix it automatically though.
          return nil if fixable

          not_fixable(msg)
        end

        def max_overlap
          Settings.audio_recording_max_overlap_sec
        end

        def fake_recording(harvest_item)
          recorded_date = harvest_item.info.file_info[:recorded_date]
          duration_seconds = harvest_item.info.file_info[:duration_seconds]
          site_id = harvest_item.info.file_info[:site_id]

          return if recorded_date.blank? || duration_seconds.blank? || site_id.blank?

          fake_recording = AudioRecording.new({
            recorded_date:,
            duration_seconds:,
            site_id:
          })
        end
      end

      class NotOverlappingForHarvest < Validation
        code :overlapping_files_in_harvest

        def validate(harvest_item)
          recorded_date = harvest_item.info.file_info[:recorded_date]
          duration_seconds = harvest_item.info.file_info[:duration_seconds]

          # if any of the above a blank, then we can't check for overlap
          # prior validations should have caught this so we'll skip this
          # check until next time
          return if recorded_date.blank? || duration_seconds.blank?

          overlaps_in_this_job = harvest_item.overlaps_with
          return if overlaps_in_this_job.empty?

          max_overlap = Settings.audio_recording_max_overlap_sec

          fixable = true
          fake_recording = AudioRecording.new({
            recorded_date:,
            duration_seconds:
          })

          msg_lines = []
          overlaps_in_this_job.map do |item|
            other = AudioRecording.new({
              recorded_date: item.info.file_info[:recorded_date],
              duration_seconds: item.info.file_info[:duration_seconds]
            })

            report = AudioRecordingOverlap.get_overlap_info(fake_recording, other)
            overlap_amount = report[:overlap_amount]
            can_fix = report[:can_fix]

            can_fix &&= overlap_amount <= max_overlap
            fixable &&= can_fix

            msg = "#{item.path} overlaps with #{other.path} by #{overlap_amount} seconds. This is #{can_fix ? 'fixable' : 'not fixable'}"
            msg_lines << msg
          end

          final_msg = <<~MSG
            An overlap was detected:\n #{msg_lines.join("\n")}}}
          MSG

          # we're not reurning a fixable validation here because it's not something
          # user can fix. We will fix it automatically though.
          return if fixable

          not_fixable(final_msg)
        end
      end
    end
  end
end
