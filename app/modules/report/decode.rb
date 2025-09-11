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

      # but perhaps you could use rail's own range deserializer? https://github.com/rails/rails/blob/4b7fb1d14b954d2348d2065ff955466479509656/activerecord/lib/active_record/connection_adapters/postgresql/oid/range.rb#L7
      #
      #   using this worked thanks. the output now looks like:
      #   {:range=>"2025-01-03 00:00:00 UTC...2025-01-03 16:40:00 UTC", .. }
      #   instead of an array before ['2025-01-02T00:00:00.000+00:00', '2025-01-03T00:00:00.000+00:00']
      #
      # Yeah so, I think what's happening is we get a Ruby range, and the default JSON serializer is to_s/inspecting the value.
      # It's not great for two reasons: 1) the ... synax is a distinctly Ruby idiom (AFAIK?) and 2) The date strings are a different format.
      # I'd either register a JSON serializer for the Range object to emit the tuple variant or do a post query transform on range objects.
      # Or we could not use the postgres serializer.
      # Aside: using a two-values tuple for spans/intervals is in no way standard, but it is something I've seen used commonly in D3. I'm opting for that pattern because it is simple and space efficient in JSON, but it's arguably not self-describing in any way.
    end

    def row_with_tsrange(result, key)
      json result[key] do |item|
        transform_tsrange.call(item)
      end
    end
  end
end
