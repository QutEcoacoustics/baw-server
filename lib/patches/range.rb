# frozen_string_literal: true

module BawWeb
  module Range
    def as_json(_options = nil)
      [first, last]
    end
  end
end

Range.prepend(BawWeb::Range)
