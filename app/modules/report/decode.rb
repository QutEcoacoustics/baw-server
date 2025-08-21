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
          .map { |i| ActiveSupport::JSON.decode(i) }
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
