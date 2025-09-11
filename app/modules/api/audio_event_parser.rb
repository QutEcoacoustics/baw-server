# frozen_string_literal: true

require 'dry/validation'
require 'dry/monads'
require 'dry/monads/do'

Dry::Validation.load_extensions(:monads)

module Api
  # A class used to parse audio events
  class AudioEventParser
    # Regex used to match at least one AviaNZ event structure
    AVIANZ_EVENT = /\[([\d.-]+,\s*){4}/

    # we don't allow a user to set index, only our code can set it
    # Using a random symbol should almost guarantee no possible path for a user to set it
    CUSTOM_INDEX = SecureRandom.uuid.to_sym

    KEY_MAPPINGS = {
      audio_recording_id: EitherTransformer.new(
        KeyTransformer.new(:audio_recording_id, :recording_id, :RecordingID),
        FriendlyAudioRecordingNameTransformer.new(:filename, :Filename, :'IN FILE')
      ),
      channel: IntTransformer.new(:channel, :CHANNEL),
      duration: FloatTransformer.new(:duration, :DURATION),
      end_time_seconds: FloatTransformer.new(
        :end_offset_seconds,
        :event_end_seconds,
        :end_time_seconds,
        :'end time',
        :'End (s)',
        :'End Time (s)',
        :end_offset,
        :end
      ),
      high_frequency_hertz: FloatTransformer.new(:high_frequency_hertz, :'High Freq (Hz)', :Fmax, allow_nil: true),
      is_reference: BoolTransformer.new(:is_reference),
      low_frequency_hertz: FloatTransformer.new(:low_frequency_hertz, :'Low Freq (Hz)', :Fmin, allow_nil: true),
      start_time_seconds: FloatTransformer.new(
        :start_offset_seconds,
        :start_time_seconds,
        :start_offset,
        :event_start_seconds,
        :'start time',
        :'Start (s)',
        :'Begin Time (s)',
        :start,
        :OFFSET
      ),
      score: FloatTransformer.new(
        :score,
        :Confidence,
        # the probability the event is a true positive - JCU format
        :TP,
        allow_nil: true
      ),
      tags: TagTransformer.new(
        :tag,
        :tags,
        :name,
        :annotation,
        :common_name_tags,
        :species_name_tags,
        :'Scientific name',
        :'Common name',
        :other_tags,
        :label,
        :'MANUAL ID',
        :'AUTO-ID'
      )
    }.freeze

    REJECTION_SCORE_BELOW_MINIMUM = :score_below_minimum
    REJECTION_REASONS = [
      REJECTION_SCORE_BELOW_MINIMUM
    ].freeze

    include Dry::Monads::Do.for(:parse)
    include Dry::Monads[:result]
    include SemanticLogger::Loggable
    include BawApp::Inspector

    inspector includes: [:audio_event_import, :additional_tags, :provenance, :creator, :any_error]

    # @return [TagCache]
    attr_accessor :tag_cache

    # @return [AudioEventImportFile]
    attr_accessor :audio_event_import_file

    # @return [Array<Tag>]
    attr_accessor :additional_tags

    # @return [Provenance, nil]
    attr_accessor :provenance

    # @return [Integer, nil]
    attr_accessor :override_audio_recording_id

    # @return [User]
    attr_accessor :creator

    # @return [Boolean]
    def any_error?
      @any_error ||= false
    end

    # @return [Dry::Validation::Contract]
    def audio_event_validator(will_commit:, score_minimum:)
      @audio_event_validator ||= AudioEventValidation.new(commit: will_commit, score_required: score_minimum.present?)
    end

    # @param import [AudioEventImportFile] the import we're attaching to
    # @param creator [User] the user used to create the audio events
    # @param additional_tags [Array<Tag>>] any tags we wish to add to imported events
    # @param provenance [Provenance, nil] the provenance to use for the imported events
    # @param audio_recording [AudioRecording, nil] an audio recording to use
    #   which will override any in the file or filename (a scope).
    # @param score_minimum [Numeric, nil] if set, any events with a score below this will be rejected
    def initialize(
      import_file,
      creator,
      additional_tags: [],
      provenance: nil,
      audio_recording: nil,
      score_minimum: nil
    )
      raise 'import_file must be an AudioEventImportFile' unless import_file.is_a?(AudioEventImportFile)
      raise 'additional_tags must be Tags' unless additional_tags&.all? { |t| t.is_a?(Tag) }
      raise 'creator must be a User' unless creator.is_a?(User)
      raise 'provenance must be a Provenance' unless provenance.nil? || provenance.is_a?(Provenance)
      unless audio_recording.nil? || audio_recording.is_a?(AudioRecording)
        raise 'audio_recording must be an AudioRecording'
      end
      raise 'score_minimum must be a number or nil' unless score_minimum.nil? || score_minimum.is_a?(Numeric)

      self.audio_event_import_file = import_file
      self.creator = creator
      self.additional_tags = additional_tags
      self.provenance = provenance
      self.override_audio_recording_id = audio_recording&.id

      self.tag_cache = TagCache.new(
        import_id: import_file.audio_event_import.id,
        creator_id: creator.id
      )

      @score_minimum = score_minimum

      # @type [Array<Hash>]
      @audio_events = []
      # @type [Array<Array<Tag>>]
      @tag_list = []
      # @type [Array<Array<Hash>>]
      @errors = []
      # @type [Array<Integer>] the returned result from insert_all! for audio_events
      #  containing the ids of the created audio events in order.
      @audio_event_ids = []

      # @type [Array<Array<Hash>>, nil] the reasons for rejections for each event
      #   These are not fatal errors, just reasons why we may have filtered out an event.
      #   Has the same structure as validation messages in @errors
      @rejections = nil
      @rejection_count = 0

      @audio_recording_ids = Set.new
    end

    # Returns any new [Tag] instances created while parsing
    # @return [Set<Tag>]
    def new_tags
      tag_cache.cache.values.filter(&:new_record?).to_set
    end

    # Returns the parsed events in a format suitable for the API.
    # @return [Array<Hash>]
    def serialize_audio_events
      size = @audio_events.length

      return [] if size.zero?

      (0...size).map do |i|
        event = @audio_events[i]
        event[:tags] = @tag_list[i].map { |tag| tag_to_hash(tag) }
        event[:errors] = @errors[i]&.errors(full: false)&.map(&:to_h) || []
        event[:rejections] = @rejections[i] || []
        event[:id] = @audio_event_ids[i]

        event
      end
    end

    # Returns a summary of the errors encountered while parsing.
    # Returns one of each unique error message.
    # @return [Array<String>]
    def summarize_errors
      # output only unique errors for a compact summary of errors
      @errors
        .flat_map { |e| e.errors(full: true).messages.map(&:to_s) }
        .uniq
    end

    # Parse a file of audio events and commit them to the database.
    # First saves the host record, and then calls {#parse} to parse the file.
    # If any of the steps fail, a transaction rollback is performed.
    # @param contents [String] the file to parse
    # @param filename [String] the name of the file to parse
    # @return [Dry::Monads::Result] the result of the operation
    def parse_and_commit(contents, filename)
      result = nil

      ActiveRecord::Base.transaction do
        # create our parent record
        logger.measure_info('save audio import') do
          @audio_event_import_file.save!
        end

        # we need an id to link to the file import for audio events,
        # # so this happens after the save
        logger.measure_info('parsing events') do
          result = parse(contents, filename, will_commit: true)
        end

        raise ActiveRecord::Rollback if result.failure?

        # retrieve the subset of audio events to save
        accepted_audio_events => [accepted_event_indices, events_to_commit]

        # save the audio events
        # @type [Array<Integer>]
        inserted_ids = logger.measure_info('save audio events', count: events_to_commit.count) {
          AudioEvent
            .insert_all!(events_to_commit, record_timestamps: true)
            .pluck('id')
        }

        update_ids_with_inserted_ids(accepted_event_indices, inserted_ids)

        import_permissions_check(@audio_event_import_file)

        # collect all Tag objects referenced by accepted events
        accepted_tags = @tag_list.values_at(*accepted_event_indices).flatten.compact.to_set

        # only save new (unsaved) tags that are actually used by accepted events
        new_tags_to_save = new_tags & accepted_tags

        logger.measure_info('save new tags', count: new_tags_to_save.count) do
          new_tags_to_save.each(&:save!)
        end

        # expand tags to taggings
        accepted_taggings = logger.measure_info('expand taggings') {
          expand_to_taggings(accepted_event_indices)
        }

        logger.measure_info('save taggings', count: accepted_taggings.count) do
          Tagging.insert_all!(accepted_taggings, returning: false, record_timestamps: true)
        end

        # lastly update the import file stats (this is done before saving as well in #parse)
        audio_event_import_file.imported_count = inserted_ids.size
        audio_event_import_file.parsed_count = @audio_events.length
        audio_event_import_file.save!

        result = Success()
      end

      result
    end

    # Parse a file of audio events.
    # Sets the [audio_events] and [tag_list] and [errors] attributes.
    # @param contents [String] the file to parse
    # @param filename [String] the name of the file to parse
    # @return [Dry::Monads::Result<Array<Hash>>] the parsed audio events
    def parse(contents, filename, will_commit: false)
      # test type CSV or JSON and do basic validation
      data = parse_format(contents)

      return data if data.is_a?(Failure)

      size = data.length

      # update stats on source object - done again in #parse_and_commit after save
      audio_event_import_file.imported_count = 0
      audio_event_import_file.parsed_count = size
      audio_event_import_file.minimum_score = @score_minimum if @score_minimum.present?

      return Failure('must have at least one audio event but 0 were found') if size.zero?

      default_audio_recording_id = parse_filename(filename)

      # transform

      # this layout looks convoluted but we're trying to optimize a hot loop:
      # array of structs is often slower arrays of arrays
      @any_error = false
      @audio_events = Array.new(size)
      @tag_list = Array.new(size)
      @errors = Array.new(size)
      @rejections = Array.new(size)

      (0...size).each do |i|
        datum = data[i]
        transform(i, datum, default_audio_recording_id, will_commit:)
      end

      validate_audio_recording_ids_exist_and_we_have_permission

      return Failure('Validation failed') if any_error?

      return Failure('All events were rejected') if @rejection_count == size

      Success()
    end

    private

    # Returns the subset of audio events that were accepted (not rejected).
    # @return [(Array<Integer>, Array<Hash>)] the indices and events that were accepted
    def accepted_audio_events
      accepted_indices = []
      accepted_events = []
      @audio_events.each_with_index do |event, index|
        next if @rejections[index].present?

        accepted_indices << index
        accepted_events << event
      end

      [accepted_indices, accepted_events]
    end

    def update_ids_with_inserted_ids(accepted_event_indices, inserted_ids)
      raise 'sanity check failed' unless accepted_event_indices.length == inserted_ids.length

      accepted_event_indices.each_with_index do |event_index, index|
        @audio_event_ids[event_index] = inserted_ids[index]
      end
    end

    # @return [Array<Hash>] a list of taggings to add
    def expand_to_taggings(accepted_event_indices)
      accepted_event_indices.flat_map { |accepted_index|
        audio_event_id = @audio_event_ids[accepted_index]
        tags = @tag_list[accepted_index]

        tags.map { |tag|
          { audio_event_id:, tag_id: tag.id, creator_id: creator.id }
        }
      }
    end

    def csv?(content)
      # match a possibly quoted header
      content&.start_with?(/"?[^,\n\r\{\[]+"?,/)
    end

    def tsv?(content)
      content&.start_with?(/"?[^\t\n\r\{\[]+"?\t/)
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
          header_converters: :symbol_raw,
          col_sep: "\t"
        )
        # filter out non-spectrogram views
        # Raven can duplicate annotations in the waveform view
        .filter { |audio_recording| audio_recording[:View] =~ /Spectrogram.*/ }
        .map(&:to_h)
    end

    def avianz?(content)
      # Need to differentiate from other JSON formats
      # there's been a Operator key in the JSON for nearly 6 years
      # https://github.com/smarsland/AviaNZ/blame/794343335b81d5fa6a3be299930eab8ba5a139cd/Segment.py#L276-L284
      content&.start_with?('[') && content.include?('Operator') && content.match?(AVIANZ_EVENT)
    end

    def parse_avianz(contents)
      interim = parse_json(contents)

      # need to normalize the data to an array of hashes
      # The AviaNZ format is:
      # [
      #   { /* A metadata object */ },
      #   ...{
      #     /* An array of audio events */
      #     [ start, end, low, high, [
      #       { /* A tag object */ },
      #       ]
      #     ]
      #   }
      # ]

      interim => [metadata, *audio_events]

      audio_events.each_with_index.flat_map { |event, index|
        event => [start_time, end_time, low, high, tags]
        tags.map { |tag|
          {
            start_time_seconds: start_time,
            end_time_seconds: end_time,
            low_frequency_hertz: low,
            high_frequency_hertz: high,
            score: tag[:certainty],
            # We expand multiple tags into multiple events,
            # So they should have the same import index
            CUSTOM_INDEX => index,
            tags: [
              tag[:species]
            ],
            # we don't parse these fields currently, but maybe in the future
            creator: metadata[:operator],
            verifier: metadata[:reviewer]
          }
        }
      }
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
          header_converters: :symbol_raw,
          strip: true
        )
        .map(&:to_h)
    end

    def parse_tsv(contents)
      CSV
        .parse(
          contents,
          headers: true,
          empty_value: nil,
          skip_blanks: true,
          header_converters: :symbol_raw,
          col_sep: "\t"
        )
        .map(&:to_h)
    end

    def parse_format(contents)
      return Failure('File must not be empty') if contents.blank?

      # parse into hashes
      if csv?(contents)
        parse_csv(contents)
      # Raven is a specialized tsv format, make sure it's detected
      # before other tsv formats
      elsif raven?(contents)
        parse_raven(contents)
      elsif tsv?(contents)
        parse_tsv(contents)
      # AviaNZ is a JSON format but it needs a transform, make sure it's detected
      elsif avianz?(contents)
        parse_avianz(contents)
      elsif json?(contents)
        parse_json(contents)
      else
        return Failure('File must be a CSV/TSV with headers, a Raven file, or a JSON array')
      end => data

      return Failure('data must be an array') unless data.is_a?(Array)

      data
    end

    def parse_filename(filename)
      match = AudioRecording::FRIENDLY_NAME_REGEX.match(filename)

      return nil if match.nil?

      match[:id].to_i
    end

    def validate_audio_event(data, will_commit:)
      audio_event_validator(will_commit:, score_minimum: @score_minimum).call(data)
    end

    # Converts a hash into an audio_event
    # @param index [Integer] the index of the audio event in the file
    # @param hash [Hash] the hash to convert
    # @param default_audio_recording_id [Integer] the default audio recording id to use
    def transform(index, hash, default_audio_recording_id, will_commit:)
      raise 'hash must be a Hash' unless hash.is_a?(Hash)

      # pick out the keys and transform the values
      KEY_MAPPINGS
        .filter_map { |key, transformer|
          transformer
            .extract_key(hash)
            .fmap { [key, _1] }
            .value_or(nil)
        }
        .to_h => values

      normalize_duration_to_end_time(values)

      tags = values.delete(:tags) || []

      # add additional tags
      # load as Tag models
      tags = deduplicate_tags(tag_cache.map_tags(tags) + additional_tags)

      # extract an audio recording id, or use a default from a filename if not found
      audio_recording_id = choose_audio_recording_id(values, default_audio_recording_id)

      audio_event = {
        audio_event_import_file_id: audio_event_import_file.id,
        import_file_index: hash.fetch(CUSTOM_INDEX, index),
        provenance_id: provenance&.id,
        creator_id: creator.id,
        audio_recording_id:,
        tags: tags.map(&:text),
        **values
      }

      result = validate_audio_event(audio_event, will_commit:)

      @any_error = true if result.failure?

      final = result.to_h.except(:tags)

      @audio_events[index] = final
      @tag_list[index] = tags
      @errors[index] = result

      apply_rejections(final, index)

      # don't want to add extra validation messages if the audio recording id is already invalid
      @audio_recording_ids.add(audio_recording_id) unless result.error?(:audio_recording_id)
    end

    def normalize_duration_to_end_time(values)
      return if values.key?(:start_time_seconds) && values.key?(:end_time_seconds)

      return unless values.key?(:duration) && values.key?(:start_time_seconds)

      values.delete(:duration) => duration

      values[:end_time_seconds] = values[:start_time_seconds] + duration
    end

    def deduplicate_tags(tags)
      # we have two cases:
      # 1. Tag models that have been loaded from the database, they have an id
      # 2. New tags that have been created in this import, they don't have an id
      existing, new = tags.partition(&:persisted?)

      # first deduplicate the existing tags
      existing = existing.uniq(&:id)

      # then deduplicate the new tags
      new = new.uniq(&:text)

      existing + new
    end

    # Choose an audio recording ID to use for an audio event.
    # Will always use the override if set.
    # @param values [Hash] the values to choose from
    # @param default_audio_recording_id [Integer] the default audio recording id to use
    # @return [Integer] the audio recording id to use
    def choose_audio_recording_id(values, default_audio_recording_id)
      item_id = values.delete(:audio_recording_id)

      return override_audio_recording_id if override_audio_recording_id

      converted_id = item_id&.to_i_strict
      converted_default_audio_recording_id = default_audio_recording_id&.to_i_strict

      # return the first valid converted value we find
      return converted_id if converted_id
      return converted_default_audio_recording_id if converted_default_audio_recording_id

      # if we can't convert the values, return the original value
      # so the validation can catch it
      return item_id if item_id

      default_audio_recording_id
    end

    def apply_rejections(event, index)
      # Should we reject events below the score threshold?
      return if @score_minimum.nil?

      event.fetch(:score, nil) => score

      # we're only here if score filtering is enabled, so reject events that have no score
      # as well as those below the threshold
      return unless score.nil? || score < @score_minimum

      (@rejections[index] ||= []) << { score: REJECTION_SCORE_BELOW_MINIMUM }
      @rejection_count += 1
    end

    def validate_audio_recording_ids_exist_and_we_have_permission
      # can happen if all audio recording ids are invalid (non-integers)
      return if @audio_recording_ids.empty?

      # Get the set of audio recording IDs to check
      # Check which ones actually exist and which one don't
      does_not_exist = 1
      has_no_permission = 2

      source_table = Arel::Table.new('_audio_recording_ids')
      permissions_table = Arel::Table.new('permissions')
      permissions = Access::ByPermission
        .audio_recordings(creator, levels: Access::Permission::WRITER_OR_ABOVE)
        .select(:id)
        .arel
        .as(permissions_table.name)

      audio_recordings_table = Arel::Table.new('audio_recordings')

      exists_expression = audio_recordings_table[:id].eq(nil)
      permission_expression = permissions_table[:id].eq(nil)

      #Arel::SelectManager.new(source_query)
      source_table
        .join(audio_recordings_table, Arel::Nodes::OuterJoin).on(
          source_table[:id].eq(audio_recordings_table[:id])
        )
        .join(permissions, Arel::Nodes::OuterJoin).on(
          source_table[:id].eq(permissions_table[:id])
        )
        .where(
          audio_recordings_table[:id].eq(nil).or(permissions_table[:id].eq(nil))
        )
        .project(
          source_table[:id].as('audio_recording_id'),
          Arel::Nodes::Case.new
          .when(exists_expression).then(does_not_exist)
          .when(permission_expression).then(has_no_permission)
          .else(0)
          .as('error')
        ) => query

      results = nil
      AudioRecording.with_connection do |connection|
        connection.transaction do
          connection.create_table(source_table.name, id: false, temporary: true) do |t|
            t.bigint :id
          end
          insert = Arel::InsertManager.new
          insert.into(source_table)
          insert.columns << source_table[:id]
          insert.values = insert.create_values_list(@audio_recording_ids.map { |x| [x] })
          connection.exec_query(insert.to_sql)

          connection
            .select_all(query.to_sql, 'Check audio recording IDs exist and have permission')
            .to_a => results
        end
      ensure
        # handle rollback or any other errors
        connection.drop_table(source_table.name, if_exists: true)
      end

      return if results.empty?

      # we should only be left with audio recording IDs that are erroneous
      @any_error = true

      # create a hash for fast lookup
      errors = results.to_h { |row| [row['audio_recording_id'], row['error']] }

      # prepare some error messages that can be reused
      does_not_exist_error = Dry::Validation::Message.new('does not exist', path: :audio_recording_id)
      has_no_permission_error = Dry::Validation::Message.new(
        'you do not have permission to add audio events to this recording',
        path: :audio_recording_id
      )

      # Add an error to the relevant events for each missing ID
      @audio_events.each_with_index do |audio_event, index|
        id = audio_event[:audio_recording_id]

        error = errors.fetch(id, nil)

        next if error.nil?

        @errors[index].add_error(does_not_exist_error) if error == does_not_exist
        @errors[index].add_error(has_no_permission_error) if error == has_no_permission
      end
    end

    # TODO: this should never be needed now that we do the permissions check in
    # the audio event validation
    def import_permissions_check(import_file)
      logger.measure_info('import permissions query') do
        # structuring the query this way does all the checking on the db server
        # and only returns one number - the number of unauthorized audio recordings
        # accessed
        permission_table = Arel::Table.new('permissions')
        count_table = Arel::Table.new('counts')

        filter = Arel.star.count.filter(
          permission_table[:id].eq(nil)
        ).as('count')

        grouped = AudioEvent
          .arel_table
          .where(AudioEvent.arel_table[:audio_event_import_file_id].eq(import_file.id))
          .group(:audio_recording_id)
          .project(filter)

        permissions = Access::ByPermission
          .audio_recordings(creator, levels: Access::Permission::WRITER_OR_ABOVE)
          .select(:id)
          .arel
          .as(permission_table.name)

        counts = grouped
          .join(permissions, Arel::Nodes::OuterJoin)
          .on(AudioEvent.arel_table[:audio_recording_id].eq(permission_table[:id]))
          .as(count_table.name)

        count = Arel::SelectManager.new(counts).project(count_table['count'].sum)

        ActiveRecord::Base.connection.exec_query(count.to_sql).first['sum']
      end => result

      return if result.zero?

      raise CanCan::AccessDenied, 'You do not have permission to add audio events to all audio recordings'
    end

    def tag_to_hash(tag)
      { id: tag.id, text: tag.text }
    end
  end
end
