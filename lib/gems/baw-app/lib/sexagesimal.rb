# frozen_string_literal: true

module BawApp
  # Handles parsing of sexagesimal values.
  # ripped of of safe yaml
  # https://github.com/collabnix/kubelabs/blob/c8578a2866e4be0204b39ae56037b056302fdf4e/.bundles_cache/ruby/2.6.0/gems/safe_yaml-1.0.5/lib/safe_yaml/parse/sexagesimal.rb#L3
  module Sexagesimal
    INTEGER_MATCHER = /\A[-+]?[0-9][0-9_]*(:[0-5]?[0-9])+\Z/
    FLOAT_MATCHER = /\A[-+]?[0-9][0-9_]*(:[0-5]?[0-9])+\.[0-9_]*\Z/

    # @param value [String]
    # @return [Float]
    def self.parse(value)
      before_decimal, after_decimal = value.split('.')

      whole_part = 0.0
      multiplier = 1

      before_decimal = before_decimal.split(':')
      until before_decimal.empty?
        whole_part += (Float(before_decimal.pop) * multiplier)
        multiplier *= 60
      end

      result = whole_part
      result += Float(".#{after_decimal}") unless after_decimal.nil?
      result *= -1 if value[0] == '-'
      result
    end
  end
end
