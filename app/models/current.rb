# frozen_string_literal: true

# New in Rails 5.2, the "current" concept.
# https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html#method-c-attribute
class Current < ActiveSupport::CurrentAttributes
  attribute :user
end
