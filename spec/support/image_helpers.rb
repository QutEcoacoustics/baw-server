# frozen_string_literal: true

module ExampleImageHelpers
  # Calculates a hash on just the image data of an image, ignoring metadata
  # @param [String] path the path of the file to check
  # @return [String] a hex digest of the hash
  def calculate_image_data_hash(path)
    result = `identify  -format "%#" #{path}`

    raise 'failed to run image magick' if $CHILD_STATUS.exitstatus != 0

    result
  end
end
