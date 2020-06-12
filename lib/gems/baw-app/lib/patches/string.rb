class String
  def trim(chars_to_replace, char_to_insert)
    return nil if self.nil?

    self.to_s.gsub(/^[#{chars_to_replace}]+|[#{chars_to_replace}]+$/, char_to_insert)
  end
end