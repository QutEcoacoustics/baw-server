# frozen_string_literal: true

require_relative 'discardable/errors'
require_relative 'discardable/model'
require_relative 'discardable/relation'

# The main module for the discard functionality.
# Include this in your application model.
# It defines helper methods for all models - even those that are not discardable.
#
# @example
#    class ApplicationRecord < ActiveRecord::Base
#      include Discardable
#    end
#
#    class Post < ApplicationRecord
#     acts_as_discardable
#    end
#
module Discardable
  extend ActiveSupport::Concern

  included do
    ActiveRecord::Relation.include(Discardable::Relation)
  end

  # Class methods for the discard module.
  module ClassMethods
    def acts_as_discardable(_options = {})
      include Discardable::Model
    end

    # Does this model support soft deletes?
    # @return [Boolean] true if the model supports soft deletes
    def discardable?
      included_modules.include?(Discardable::Model)
    end
  end

  # Does this instance support soft deletes?
  # @return [Boolean] true if the instance supports soft deletes
  def discardable?
    self.class.discardable?
  end
end
