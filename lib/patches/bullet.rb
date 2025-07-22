# frozen_string_literal: true

module Baw
  module Bullet
    # Disable Bullet for the duration of the block
    def disable_for
      previous = enable?
      self.enable = false
      yield
    ensure
      self.enable = previous
    end
  end
end

Bullet.extend(Baw::Bullet) if defined?(Bullet)

# @!parse
#  module Bullet
#    extend Baw::Bullet
#  end
