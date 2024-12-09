# frozen_string_literal: true

# Extensions to the Pathname class
class Pathname
  raise 'Pathname#touch is already implemented' if defined?(touch)

  # creates the file
  def touch
    FileUtils.touch(self)

    self
  end

  def hidden?
    basename.to_s.start_with?('.')
  end
end
