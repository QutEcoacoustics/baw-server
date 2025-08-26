# frozen_string_literal: true

module Report
  module Decode
    module_function

    def decode(row, decoder, &transform)
      decoded = decoder.decode(row)
      transform ? decoded.map(&transform) : decoded
    end

    def array(row, &transform)
      default_block = proc { |x| x.to_i }
      decode(row, PG::TextDecoder::Array.new, &transform || default_block)
    end

    def json(row, &)
      decode(row, PG::TextDecoder::JSON.new, &)
    end

    def transform_tsrange
      lambda { |row|
        row['range'] = row['range']
          .delete_prefix('[')
          .delete_suffix(')')
          .split(',')
          .map { |t| Time.parse(t).utc }
        # .map { |i| ActiveSupport::JSON.decode(i) }

        # TODO: talk about the time formatting
        #
        # consider this raw output for a 'range' value:
        # "[\"2025-01-01 00:00:00\",\"2025-01-01 16:40:00\")"
        #  when split, the first element is "\"2025-01-01 00:00:00\""
        #
        # JSON.decode(t) => "2025-01-01 00:00:00"         # Class: String
        # Time.parse(t).utc => 2025-01-01 00:00:00 UTC    # Class: Time
        #
        # When it becomes the api_result, the Time version gets converted into a String that looks like this:
        # 2025-01-01T00:00:00.000Z. So it's clearer that it's a UTC time than just "2025-01-01 00:00:00"
        row
      }
    end

    def row_with_tsrange(result, key)
      json result[key] do |item|
        transform_tsrange.call(item)
      end
    end
  end
end
