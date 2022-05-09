# frozen_string_literal: true

module AudioHelper
  module Example
    def generate_audio(destination, sine_frequency:, duration: 30, sample_rate: 11_025)
      raise unless destination.is_a?(Pathname)

      destination = destination.expand_path

      raise 'invalid extension' unless ['.mp3', '.wav', '.flac'].include?(destination.extname)

      command = "sox -n -r #{sample_rate} #{destination} synth #{duration} sine #{sine_frequency}"

      stdout, stderr, status = Open3.capture3(command)
      logger.info('generating temporary audio file', destination:, stdout:, stderr:, status:)

      raise 'audio generation failed; file does not exist' unless destination.exist?

      destination
    end
  end
end
