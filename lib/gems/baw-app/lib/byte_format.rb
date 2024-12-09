# frozen_string_literal: true

module BawApp
  # A module for parsing byte size strings
  module ByteSize
    # decodes a string containing a byte size with units as emitted by PBS
    # stolen from
    # https://github.com/openpbs/openpbs/blob/618c69f06e3580cf099b676ea0e437b98006d376/src/modules/python/pbs/v1/_base_types.py#L426
    def self.parse(string)
      return nil unless string.is_a?(String)

      case string[-1]
      when 'b', 'B'
        1
      when 'w', 'W'
        8
      else
        return nil
      end => word_size

      case string[-2]
      when 'k', 'K'
        2**10
      when 'm', 'M'
        2**20
      when 'g', 'G'
        2**30
      when 't', 'T'
        2**40
      when 'p', 'P'
        2**50
      else
        1
      end => scale

      string.to_i * scale * word_size
    end
  end
end
