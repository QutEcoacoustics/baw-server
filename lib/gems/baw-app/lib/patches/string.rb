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
end
