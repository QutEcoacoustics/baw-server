# frozen_string_literal: true

module Api
  class AudioEventParser
    # the skeptical reader might ask why we're not using our own model validations
    # and why we're duplicating validations here. Simply put, we're constructing
    # a hash (not a model) for use with insert_all!. Given we don't need the model
    # we don't want the cost of creating it either, or the risk of any
    # database query being made.
    # We also have different validations requirements for audio events that are
    # imported.
    # Our tests should assert that all inserted events are valid after being
    # loaded from the database.
    class AudioEventValidation < Dry::Validation::Contract
      option :commit

      # no coercion here; everything should have already been coerced
      schema do
        required(:audio_recording_id).filled(:integer, gt?: 0)
        optional(:channel).maybe(:integer, gteq?: 0)
        required(:start_time_seconds).filled(:float, gteq?: 0)
        required(:end_time_seconds).filled(:float, gteq?: 0)
        optional(:low_frequency_hertz).maybe(:float, gteq?: 0)
        optional(:high_frequency_hertz).maybe(:float, gteq?: 0)
        required(:audio_event_import_file_id).maybe(:integer, gt?: 0)
        required(:import_file_index).filled(:int?, gteq?: 0)
        required(:provenance_id).maybe(:integer, gt?: 0)
        optional(:score).maybe(:float)
        optional(:is_reference).filled(:bool)
        # created_at is still set by rails
        required(:creator_id).filled(:integer, gt?: 0)
        optional(:tags).array(:str?, :filled?)
      end

      rule(:audio_event_import_file_id) do
        if values[:audio_event_import_file_id].nil? && commit
          key.failure('`audio_event_import_file_id` must be present if commit is true')
        end
      end

      rule(:start_time_seconds, :end_time_seconds) do
        start = values[:start_time_seconds]
        stop = values[:end_time_seconds]

        next if stop.nil?

        next if start <= stop

        key.failure('must be less than or equal to `end_time_seconds`')
      end

      rule(:low_frequency_hertz, :high_frequency_hertz) do
        low = values[:low_frequency_hertz]
        high = values[:high_frequency_hertz]

        next if high.nil?

        next if low <= high

        key.failure('must be less than or equal to `high_frequency_hertz`')
      end

      # rule(:audio_recording_id) do
      # end
    end
  end
end
