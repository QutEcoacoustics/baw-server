# frozen_string_literal: true

# New in Rails 5.2, the "current" concept.
# https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html#method-c-attribute
class Current < ActiveSupport::CurrentAttributes
  # @!attribute [rw] user
  #   @return [User, nil] The current user for the request
  attribute :user

  # @!attribute [rw] ability
  #   @return [Ability] The current ability for the request
  attribute :ability

  # @!attribute [rw] action_name
  #   @return [String] The current action for the request
  attribute :action_name

  # @!attribute [rw] path
  #  @return [String] The current path for the request
  attribute :path

  # @!attribute [rw] method
  #   @return [String] The current method for the request
  attribute :method

  # @!parse
  #   extend self
end
