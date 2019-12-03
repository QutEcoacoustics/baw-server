class String
  def trim(chars_to_replace, char_to_insert)
    "#{self}".gsub(/^[#{chars_to_replace}]+|[#{chars_to_replace}]+$/, char_to_insert)
  end
end