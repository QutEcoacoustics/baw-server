# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # All validations that the harvester will check
      module Validations
        module_function

        def simple_validations
          # order is important in this list!
          [
            FileExists,
            IsAFile,
            FileEmpty,
            TargetType

          ]
        end

        def after_extract_metadata_validations
          # order is important in this list!
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
            NotOverlappingForHarvest,
            NotOverlapping
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
              BawWorkers::Config.logger_worker.debug('validation run', name: validation.name, status: result&.status)

              results << result

              # no point in continuing if it is impossible to resovle
              throw :halt if result&.status == ValidationResult::STATUS_NOT_FIXABLE
            end
          end

          results
        end

        class FileExists < Validation
          validation_name :does_not_exist

          def validate(harvest_item)
            path = harvest_item.absolute_path
            return if path.exist?

            not_fixable("File #{path} does not exist")
          end
        end

        class IsAFile < Validation
          validation_name :not_a_file

          def validate(harvest_item)
            not_fixable('is not a file') unless harvest_item.absolute_path.file?
          end
        end

        class FileEmpty < Validation
          validation_name :file_empty

          def validate(harvest_item)
            size = harvest_item.absolute_path.size
            return not_fixable("File has no content (#{size} bytes)") unless size.positive?
          end
        end

        class TargetType < Validation
          validation_name :invalid_extension

          def validate(harvest_item)
            path = harvest_item.absolute_path

            valid_audio_formats = Settings.available_formats.audio
            return if BawWorkers::Config.file_info.valid_ext?(path, valid_audio_formats)

            not_fixable("has invalid extension #{extension}")
          end
        end

        class RecordedDate < Validation
          validation_name :missing_date

          def validate(harvest_item)
            recorded_date = harvest_item.info.file_info[:recorded_date_local]
            return if recorded_date.present?

            fixable('We could not find a recorded date for this file')
          end
        end

        class AmbiguousDateTime < Validation
          validation_name :ambiguous_date_time

          def validate(harvest_item)
            utc_offset = harvest_item.info.file_info[:utc_offset]

            recorded_date_local = harvest_item.info.file_info[:recorded_date_local]

            # if there's no date at all there's no point in checking this
            return if recorded_date_local.blank?

            return unless utc_offset.blank?

            fixable('Only a local date/time was found, supply an UTC offset')
          end
        end

        class FutureDates < Validation
          validation_name :future_date

          def validate(harvest_item)
            recorded_date = harvest_item.info.file_info[:recorded_date]

            # If there's not date no point doing this validation (halt)
            # (prior valiations should have already caught this)
            return if recorded_date.blank?

            return if recorded_date <= Time.now

            fixable('This file has a recorded date in the future')
          end
        end

        class NoDuration < Validation
          validation_name :no_duration

          def validate(harvest_item)
            duration = harvest_item.info.file_info[:duration_seconds]
            return unless duration.blank?

            not_fixable('Could not find a duration for this file')
          end
        end

        class MinimumDuration < Validation
          validation_name :too_short

          def validate(harvest_item)
            duration = harvest_item.info.file_info[:duration_seconds]
            return if duration >= Settings.audio_recording_min_duration_sec

            not_fixable("This file is too short (#{duration} seconds)")
          end
        end

        class ChannelCount < Validation
          validation_name :channel_count

          def validate(harvest_item)
            channels = harvest_item.info.file_info[:channels]
            # channels should be an integer >= 1
            return if channels.present? && channels >= 1 && channels.is_a?(Integer)

            not_fixable("This file has too few channels (#{channels})")
          end
        end

        class SampleRate < Validation
          validation_name :sample_rate

          def validate(harvest_item)
            sample_rate = harvest_item.info.file_info[:sample_rate_hertz]
            return if sample_rate.present? && sample_rate.is_a?(Integer) && sample_rate.positive?

            not_fixable("The sample rate is invalid (#{sample_rate})")
          end
        end

        class BitRate < Validation
          validation_name :bit_rate

          def validate(harvest_item)
            bit_rate = harvest_item.info.file_info[:bit_rate_bps]
            return if bit_rate.present? && bit_rate.positive? && bit_rate.is_a?(Integer)

            not_fixable("The bit rate is invalid (#{bit_rate})")
          end
        end

        class MediaType < Validation
          validation_name :media_type

          def validate(harvest_item)
            media_type = harvest_item.info.file_info[:media_type]
            return if media_type.present? && media_type.is_a?(String)

            not_fixable("The media type is missing (#{media_type})")
          end
        end

        class NotADuplicate < Validation
          validation_name :duplicate_file

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
          validation_name :duplicate_file_in_harvest

          def validate(harvest_item)
            file_hash = harvest_item.info.file_info[:file_hash]
            not_fixable('File hash is missing') if file_hash.blank?

            # check if the file hash is already in the database for this harvest
            # if it is, then we can't add it again
            duplicates_in_this_job = harvest_item.duplicate_hash_of

            return if duplicates_in_this_job.empty?

            duplicate_msg = duplicates_in_this_job.map(&:path).join(', ')
            msg = "File duplicate of harvest items: #{duplicate_msg}. Hash: #{file_hash}"

            not_fixable(msg)
          end
        end
      end

      class HasAnUploader < Validation
        validation_name :missing_uploader

        def validate(harvest_item)
          uploader_id = harvest_item.info.file_info[:uploader_id]
          uploader = User.find_by(id: uploader_id)
          fixable('File hash is missing') if uploader_id.blank? || uploader.nil?
        end
      end

      class UploaderAllowed < Validation
        validation_name :not_allowed_to_upload

        def validate(harvest_item)
          uploader_id = harvest_item.info.file_info[:uploader_id]
          uploader = User.find_by(id: uploader_id)

          can_upload = Ability.new(uploader).can?(:harvest_audio, harvest_item.harvest)
          not_fixable('User is not allowed to upload audio recordings') unless can_upload
        end
      end

      class BelongsToASite < Validation
        validation_name :no_site_id

        def validate(harvest_item)
          site_id = harvest_item.info.file_info[:site_id]
          fixable('No site id found. Update the harvest mappings.') if site_id.blank? || Site.find_by(id: site_id).nil?
        end
      end

      class NotOverlappingForHarvest < Validation
        validation_name :overlapping_files_in_harvest

        def validate(harvest_item)
          recorded_date = harvest_item.info.file_info[:recorded_date]
          duration_seconds = harvest_item.info.file_info[:duration_seconds]
          site_id = harvest_item.info.file_info[:site_id]

          # if any of the above a blank, then we can't check for overlap
          # prior validations should have caught this so we'll skip this
          # check until next time
          return if recorded_date.blank? || duration_seconds.blank? || site_id.blank?

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

            report = AudioRecordingOverlap.get_overlap_info(fake_recording, other, max_overlap)
            overlap_amount = report[:overlap_amount]
            can_fix = report[:can_fix]

            fixable &&= can_fix

            msg = "#{harvest_item.path} overlaps with #{item.path} by #{overlap_amount} seconds. This is #{can_fix ? 'fixable' : 'not fixable'}"
            msg_lines << msg
          end

          final_msg = <<~MSG
            An overlap was detected:\n #{msg_lines.join("\n")}}}
          MSG

          # we're not returning a fixable validation here because it's not something
          # user can fix. We will fix it automatically though.
          return if fixable

          not_fixable(final_msg)
        end
      end

      class NotOverlapping < Validation
        validation_name :overlapping_files

        def validate(harvest_item)
          recording = fake_recording(harvest_item)

          # If we don't have enough information, then we can't check for overlap.
          # Prior validations should have caught this so we'll skip this
          # check until next time
          return unless recording

          result = AudioRecordingOverlap.get(recording, max_overlap)

          return if result[:overlap][:items].empty?

          msg = <<~MSG
            The file #{harvest_item.path} overlaps with the following audio recordings: #{result[:overlap][:items].join(', ')}}}
          MSG

          fixable = result[:overlap][:items].all? { |item| item[:can_fix] }
          # we're not returning a fixable validation here because it's not something
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

          AudioRecording.new({
            recorded_date:,
            duration_seconds:,
            site_id:
          })
        end
      end
    end
  end
end
