# frozen_string_literal: true

module AudioHelper
  module Example
    def generate_audio(name, sine_frequency:, duration: 30, sample_rate: 11_025)
      raise if name.blank?

      destination = temp_file(basename: name)

      raise 'invalid extension' unless ['.mp3', '.wav', '.flac'].include?(destination.extname)

      command = "sox -n -r #{sample_rate} #{destination} synth #{duration} sine #{sine_frequency}"

      stdout, stderr, status = Open3.capture3(command)
      logger.info('generating temporary audio file', destination:, stdout:, stderr:, status:)

      raise 'audio generation failed; file does not exist' unless destination.exist?

      destination
    end

    def generate_recording_name(date, prefix: nil, suffix: nil, ambiguous: false, extension: '.wav')
      raise unless date.is_a?(Time)

      prefix += '_' if prefix
      suffix = "_#{suffix}" if suffix
      extension = ".#{extension}" unless extension.start_with?('.')
      tz = ambiguous ? '' : '%z'
      date_stamp = date.strftime("%Y%m%dT%H%M%S#{tz}").to_s

      "#{prefix}#{date_stamp}#{suffix}#{extension}"
    end
  end
end
