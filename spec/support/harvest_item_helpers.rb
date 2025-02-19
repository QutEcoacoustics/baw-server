# frozen_string_literal: true

# Helper methods for creating harvest items in tests
module HarvestItemHelper
  # Example methods for harvest item creation
  module Example
    # Creates a harvest item with specified validation results
    # @param fixable [Integer] Number of fixable validation results to create
    # @param not_fixable [Integer] Number of not fixable validation results to create
    # @param sub_directories [String, nil] Optional subdirectories to append to the path
    # @param audio [Boolean] Whether to create an associated audio recording
    # @return [HarvestItem] The created harvest item
    def create_with_validations(fixable: 0, not_fixable: 0, sub_directories: nil, audio: false)
      validations = []
      fixable.times do
        validations << BawWorkers::Jobs::Harvest::ValidationResult.new(
          status: :fixable,
          name: :wascally_wabbit,
          message: nil
        )
      end
      not_fixable.times do
        validations << BawWorkers::Jobs::Harvest::ValidationResult.new(
          status: :not_fixable,
          name: :kiww_the_wabbit,
          message: nil
        )
      end

      info = BawWorkers::Jobs::Harvest::Info.new(
        validations:
      )
      time = Time.zone.now
      path = generate_recording_name(time, suffix: time.subsec.numerator.to_s)
      path = File.join(*[harvest.upload_directory_name, sub_directories, path].compact)

      recording = (create(:audio_recording, site: site, creator: owner_user, uploader: admin_user) if audio)
      create(
        :harvest_item,
        path:,
        status: HarvestItem::STATUS_METADATA_GATHERED,
        info:,
        harvest:,
        uploader: owner_user,
        audio_recording: recording
      )
    end
  end
end
