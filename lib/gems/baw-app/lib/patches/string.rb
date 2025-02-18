# frozen_string_literal: true

class String
  def trim(chars_to_replace, char_to_insert = '')
    return nil if nil?

    to_s.gsub(/^[#{chars_to_replace}]+|[#{chars_to_replace}]+$/, char_to_insert)
  end

  def ltrim(chars_to_replace, char_to_insert = '')
    return nil if nil?

    to_s.gsub(/^[#{chars_to_replace}]+/, char_to_insert)
  end

  def rtrim(chars_to_replace, char_to_insert = '')
    return nil if nil?

    to_s.gsub(/[#{chars_to_replace}]+$/, char_to_insert)
  end

  # Converts a string to an integer.
  # Convenience wrapper for https://ruby-doc.org/core-3.1.0/Kernel.html#method-i-Integer.
  # @param [Integer] base the base to use for conversion. Defaults to `10`.
  # @param [Boolean] exception whether to raise an exception if the conversion fails.
  #   Defaults to `false`.
  # @return [Integer,nil] the converted integer, or nil if the conversion fails and
  #   `exception` is `false`.
  # @raise [ArgumentError] if the conversion fails and `exception` is `true`.
  def to_i_strict(base: 10, exception: false)
    Integer(self, base, exception:)
  end
end
