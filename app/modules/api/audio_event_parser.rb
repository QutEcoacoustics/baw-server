# frozen_string_literal: true

require 'dry/validation'
require 'dry/monads'
require 'dry/monads/do'

Dry::Validation.load_extensions(:monads)

module Api
  # A class used to parse audio events
  class AudioEventParser
    KEY_MAPPINGS = {
      audio_recording_id: KeyTransformer.new(:audio_recording_id),
      channel: KeyTransformer.new(:channel),
      end_time_seconds: FloatTransformer.new(:end_time_seconds, :event_end_seconds, :'End Time (s)'),
      high_frequency_hertz: FloatTransformer.new(:high_frequency_hertz, :'High Freq (Hz)'),
      is_reference: BoolTransformer.new(:is_reference),
      low_frequency_hertz: FloatTransformer.new(:low_frequency_hertz, :'Low Freq (Hz)'),
      start_time_seconds: FloatTransformer.new(:start_time_seconds, :event_start_seconds, :'Begin Time (s)'),
      tags: TagTransformer.new(:tag, :name, :annotation, :common_name_tags, :species_name_tags, :other_tags)
    }.freeze

    include Dry::Monads::Do.for(:parse)
    include Dry::Monads[:result]

    # @return [TagCache]
    attr_accessor :tag_cache

    # @return [AudioRecordingCache]
    attr_accessor :audio_recording_cache

    # @return [AudioEventImport]
    attr_accessor :audio_event_import

    # @return [Array<Tag>]
    attr_accessor :additional_tags

    # @param import [AudioEventImport] the import we're attaching to
    # @param additional_tags [Array<Tag>>] any tags we wish to add to imported events
    def initialize(import, additional_tags: [])
      raise 'import must be an AudioEventImport' unless import.is_a?(AudioEventImport)
      raise 'additional_tags must be Tags' unless additional_tags.all? { |t| t.is_a?(Tag) }

      self.audio_event_import = import
      self.additional_tags = additional_tags
      self.tag_cache = TagCache.new(import.id)
      self.audio_recording_cache = AudioRecordingCache.new
    end

    # Parse a file of audio events
    # @param contents [String] the file to parse
    # @param filename [String] the name of the file to parse
    # @return ::Dry::Monads::Result<Array<AudioEvent>>
    def parse(contents, filename)
      # test type CSV or JSON and do basic validation
      parse_format(contents) => result

      default_audio_recording_id = parse_filename(filename)

      # transform
      result.fmap do |data|
        data.map { |datum| transform(datum, default_audio_recording_id) }
      end => result

      # return audio_events
      result
    end

    def csv?(content)
      # match a possibly quoted header
      content&.start_with?(/"?[ \w]+"?,/)
    end

    def json?(content)
      # assumption: we're only ever parsing arrays
      # fail case: JSON-L or some format that has a metadata outer layer.
      content&.start_with?('[')
    end

    def raven?(content)
      content&.start_with?("Selection\t")
    end

    def parse_raven(contents)
      CSV
        .parse(
          contents,
          headers: true,
          empty_value: nil,
          skip_blanks: true,
          header_converters: :symbol,
          col_sep: "\t"
        )
        .filter { |r| r[:view] =~ /Spectrogram.*/ }
        .map(&:to_h)
    end

    def parse_json(contents)
      JSON.parse(contents, { symbolize_names: true })
    end

    def parse_csv(contents)
      CSV
        .parse(
          contents,
          headers: true,
          empty_value: nil,
          skip_blanks: true,
          header_converters: :symbol,
          strip: true
        )
        .map(&:to_h)
    end

    def parse_format(contents)
      return Failure('File must not be empty') if contents.blank?

      # parse into hashes
      if csv?(contents)
        parse_csv(contents)
      elsif json?(contents)
        parse_json(contents)
      elsif raven?(contents)
        parse_raven(contents)
      else
        return Failure('File be a CSV with headers, a Raven file, or a JSON array')
      end => data

      return Failure('data must be an array') unless data.is_a?(Array)

      Success(data)
    end

    def parse_filename(filename)
      match = AudioRecording::FRIENDLY_NAME_REGEX.match(filename)

      return nil if match.nil?

      match[:id].to_i
    end

    # Converts a hash into an audio_event
    def transform(hash, default_audio_recording_id)
      # pick out the keys and transform the values
      values = KEY_MAPPINGS.transform_values { |transformer|
        transformer.extract_key(hash)
      }

      tags = values[:tags] || []

      # add additional tags
      # load as Tag models
      values[:tags] = tag_cache.map_tags(tags) + additional_tags

      # extract an audio recording id, or use a default from a filename if not found
      audio_recording_id = values.delete(:audio_recording_id)
      audio_recording_id = default_audio_recording_id if audio_recording_id.nil?
      values[:audio_recording] = audio_recording_cache.resolve(audio_recording_id)

      AudioEvent.new(
        audio_event_import_id: audio_event_import.id,
        context: hash,
        **values
      )
    end
  end
end
