# frozen_string_literal: true

# Patches to the Integer class.
class Integer
  # A companion method to `String#to_i_strict`.
  # Allows for a nicer invocation if the value is already an integer.
  # @return [Integer] the integer itself.
  def to_i_strict(*)
    self
  end
end
