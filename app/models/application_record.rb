# frozen_string_literal: true

# Base record for all models
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  include AlphabeticalPaginatorQuery
  include RendersMarkdown
  include TimestampHelpers

  # Like `pick` except it accepts a hash of attributes and returns
  # picked values in a hash with the same keys.
  #
  # @param [Hash<Symbol,String>] attributes key-value pairs of attribute names.
  #   Values can be the names of the columns to extract, or Arel expressions.
  # @param [ActiveRecord::Relation] scope an existing relation to extend. If nil,
  #   the default scope is used.
  #
  # @return [Hash<Symbol,String>] key-value pairs where they keys are taken from
  #   the input hash and the values are the result of the query.
  #
  def self.pick_hash(attributes, scope: nil)
    scope ||= self
    attributes.keys.zip(scope.pick(*attributes.values)).to_h
  end
end
