# frozen_string_literal: true

module Api
  class AudioEventParser
    # the skeptical reader might ask why we're not using our own model validations
    # and why we're duplicating validations here. Simply put, we're constructing
    # a hash (not a model) for use with insert_all!. Given we don't need the model
    # we don't want the cost of creating it either, or the risk of a
    # database query being made.
    class AudioEventValidation < Dry::Validation::Contract
      # no coercion here; everything should have already been coerced
      schema do
        required(:audio_recording_id).filled(:integer, gt?: 0)
        optional(:channel).maybe(:integer, gteq?: 0)
        required(:start_time_seconds).filled(:float, gteq?: 0)
        required(:end_time_seconds).filled(:float, gteq?: 0)
        required(:low_frequency_hertz).filled(:float, gteq?: 0)
        required(:high_frequency_hertz).filled(:float, gteq?: 0)
        required(:audio_event_import_id).filled(:integer, gt?: 0)
        optional(:is_reference).filled(:bool)
        # created_at is still set by rails
        required(:creator_id).filled(:integer, gt?: 0)
        required(:context).filled(:hash)
      end

      rule(:start_time_seconds, :end_time_seconds) do
        start = values[:start_time_seconds]
        stop = values[:end_time_seconds]

        next if stop.nil?

        next if start <= stop

        key.failure('start_time_seconds must be less than or equal to end_time_seconds')
      end

      rule(:low_frequency_hertz, :high_frequency_hertz) do
        low = values[:low_frequency_hertz]
        high = values[:high_frequency_hertz]

        next if high.nil?

        next if low <= high

        key.failure('low_frequency_hertz must be less than or equal to high_frequency_hertz')
      end
    end
  end
end
