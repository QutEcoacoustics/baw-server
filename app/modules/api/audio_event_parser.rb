# frozen_string_literal: true

require 'dry/validation'
require 'dry/monads'
require 'dry/monads/do'
require 'set'

Dry::Validation.load_extensions(:monads)

module Api
  # A class used to parse audio events
  class AudioEventParser
    KEY_MAPPINGS = {
      audio_recording_id: KeyTransformer.new(:audio_recording_id),
      channel: IntTransformer.new(:channel),
      end_time_seconds: FloatTransformer.new(:end_time_seconds, :event_end_seconds, :'End Time (s)', :end_offset),
      high_frequency_hertz: FloatTransformer.new(:high_frequency_hertz, :'High Freq (Hz)'),
      is_reference: BoolTransformer.new(:is_reference),
      low_frequency_hertz: FloatTransformer.new(:low_frequency_hertz, :'Low Freq (Hz)'),
      start_time_seconds: FloatTransformer.new(
        :start_time_seconds,
        :event_start_seconds,
        :'Begin Time (s)',
        :start_offset
      ),
      tags: TagTransformer.new(:tag, :tags, :name, :annotation, :common_name_tags, :species_name_tags, :other_tags)
    }.freeze

    include Dry::Monads::Do.for(:parse)
    include Dry::Monads[:result]
    include SemanticLogger::Loggable
    include BawApp::Inspector

    inspector :audio_event_import, :additional_tags, :creator, :any_error

    # @return [TagCache]
    attr_accessor :tag_cache

    # @return [AudioEventImport]
    attr_accessor :audio_event_import

    # @return [Array<Tag>]
    attr_accessor :additional_tags

    # @return [User]
    attr_accessor :creator

    # @return [Boolean]
    def any_error?
      @any_error ||= false
    end

    # @return [Dry::Validation::Contract]
    def audio_event_validator
      @audio_event_validator ||= AudioEventValidation.new
    end

    # @param import [AudioEventImport] the import we're attaching to
    # @param creator [User] the user used to create the audio events
    # @param additional_tags [Array<Tag>>] any tags we wish to add to imported events
    def initialize(import, creator, additional_tags: [])
      raise 'import must be an AudioEventImport' unless import.is_a?(AudioEventImport)
      raise 'additional_tags must be Tags' unless additional_tags.all? { |t| t.is_a?(Tag) }

      self.audio_event_import = import
      self.additional_tags = additional_tags
      self.tag_cache = TagCache.new(import.id)
      self.creator = creator

      # @type [Array<Hash>]
      @audio_events = []
      # @type [Array<Array<Tag>>]
      @tag_list = []
      # @type [Array<Array<Hash>>]
      @errors = []
      # @type [Array<Integer>] the returned result from insert_all! for audio_events
      #  containing the ids of the created audio events in order.
      @audio_event_ids = []
    end

    # Returns any new [Tag] instances created while parsing
    # @return [Array<Tag>]
    def new_tags
      tag_cache.cache.values.filter(&:new_record?)
    end

    # Returns the parsed events in a format suitable for the API.
    # @return [Array<Hash>]
    def serialize_audio_events
      size = @audio_events.length

      return [] if size.zero?

      (0...size).map do |i|
        event = @audio_events[i]
        event[:tags] = @tag_list[i].map { |t| t.attributes.slice('id', 'text') }
        event[:errors] = @errors[i]&.map(&:to_h) || []
        event[:id] = @audio_event_ids[i]

        event
      end
    end

    def parse_and_commit(contents, filename)
      logger.measure_info('parsing events') do
        parse(contents, filename)
      end

      raise 'Validation failed parsing audio events' if any_error?

      ActiveRecord::Base.transaction do
        # create our parent record
        logger.measure_info('save audio import') do
          @audio_event_import.save!
        end

        # save any new tags
        new_tags = self.new_tags
        logger.measure_info('save new tags', count: new_tags.count) do
          new_tags.each(&:save!)
        end

        # save the audio events
        # @type [Array<Integer>]
        @audio_event_ids = logger.measure_info('save audio events', count: @audio_events.count) {
          AudioEvent
            .insert_all!(@audio_events, record_timestamps: true)
            .map { |result| result['id'] }
        }

        import_permissions_check(@audio_event_import)

        raise 'sanity check failed' unless @audio_event_ids.length == @audio_events.length

        # expand tags to taggings
        taggings = logger.measure_info('expand taggings') {
          expand_to_taggings
        }

        logger.measure_info('save taggings', count: taggings.count) do
          Tagging.insert_all!(taggings, returning: false, record_timestamps: true)
        end
      end
    end

    # Parse a file of audio events.
    # Sets the [audio_events] and [tag_list] and [errors] attributes.
    # @param contents [String] the file to parse
    # @param filename [String] the name of the file to parse
    def parse(contents, filename)
      # test type CSV or JSON and do basic validation
      data = parse_format(contents)

      default_audio_recording_id = parse_filename(filename)

      # transform

      # this layout looks convoluted but we're trying to optimize a hot loop:
      # array of structs is often slower arrays of arrays
      @any_error = false

      size = data.length

      @audio_events = Array.new(size)
      @tag_list = Array.new(size)
      @errors = Array.new(size)

      (0...size).each do |i|
        datum = data[i]
        transform(i, datum, default_audio_recording_id)
      end
    end

    private

    # @return [Array<Hash>] a list of taggings to add
    def expand_to_taggings
      @audio_event_ids.zip(@tag_list).flat_map { |audio_event_id, tags|
        tags.map { |tag|
          { audio_event_id:, tag_id: tag.id, creator_id: creator.id }
        }
      }
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
      raise 'File must not be empty' if contents.blank?

      # parse into hashes
      if csv?(contents)
        parse_csv(contents)
      elsif json?(contents)
        parse_json(contents)
      elsif raven?(contents)
        parse_raven(contents)
      else
        raise 'File be a CSV with headers, a Raven file, or a JSON array'
      end => data

      raise 'data must be an array' unless data.is_a?(Array)

      data
    end

    def parse_filename(filename)
      match = AudioRecording::FRIENDLY_NAME_REGEX.match(filename)

      return nil if match.nil?

      match[:id].to_i
    end

    def validate_audio_event(data)
      audio_event_validator.call(data)
    end

    # Converts a hash into an audio_event
    # @param index [Integer] the index of the audio event in the file
    # @param hash [Hash] the hash to convert
    # @param default_audio_recording_id [Integer] the default audio recording id to use
    def transform(index, hash, default_audio_recording_id)
      # pick out the keys and transform the values
      values = KEY_MAPPINGS.transform_values { |transformer|
        transformer.extract_key(hash)
      }

      tags = values.delete(:tags) || []

      # add additional tags
      # load as Tag models
      tags = tag_cache.map_tags(tags) + additional_tags

      # extract an audio recording id, or use a default from a filename if not found
      audio_recording_id = values.delete(:audio_recording_id)
      audio_recording_id = default_audio_recording_id if audio_recording_id.nil?
      audio_recording_id = audio_recording_id.to_i
      values[:audio_recording_id] = audio_recording_id

      audio_event = {
        audio_event_import_id: audio_event_import.id,
        context: hash,
        creator_id: creator.id,
        **values
      }

      result = validate_audio_event(audio_event)
      errors = result.errors

      @any_error = true unless errors.empty?

      @audio_events[index] = result.to_h
      @tag_list[index] = tags
      @errors[index] = errors
    end

    def import_permissions_check(import)
      logger.measure_info('import permissions query') do
        # structuring the query this way does all the checking on the server
        # and only returns one number - the number of unauthorized audio recordings
        # accessed
        permission_table = Arel::Table.new('permissions')
        count_table = Arel::Table.new('counts')

        filter = Arel.star.count.filter(
          permission_table[:id].eq(nil)
        ).as('count')

        grouped = AudioEvent
                  .arel_table
                  .where(AudioEvent.arel_table[:audio_event_import_id].eq(import.id))
                  .group(:audio_recording_id)
                  .project(filter)

        permissions = Access::ByPermission
                      .audio_recordings(creator, levels: :writer)
                      .select(:id)
                      .arel
                      .as(permission_table.name)

        counts = grouped
                 .join(permissions, Arel::Nodes::OuterJoin)
                 .on(AudioEvent.arel_table[:audio_recording_id].eq(permission_table[:id]))
                 .as(count_table.name)

        count = Arel::SelectManager.new(counts).project(count_table['count'].sum)

        result = ActiveRecord::Base.connection.exec_query(count.to_sql).first['sum']
        return if result.zero?
      end

      raise CanCan::AccessDenied, 'You do not have permission to add audio events to all audio recordings'
    end
  end
end
