# frozen_string_literal: true

# Base record for all models
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  include AlphabeticalPaginatorQuery
  include RendersMarkdown
  include TimestampHelpers
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # !@parse
  # extend Discardable::ClassMethods
  include Discardable

  # Like `pick` except it accepts a hash of attributes and returns
  # picked values in a hash with the same keys.
  #
  # @param [Hash<Symbol,object>] attributes key-value pairs of attribute names.
  #   Values can be the names of the columns to extract, or Arel expressions.
  # @param [::ActiveRecord::Relation] scope an existing relation to extend. If nil,
  #   the default scope is used.
  #
  # @return [Hash<Symbol,object>] key-value pairs where they keys are taken from
  #   the input hash and the values are the result of the query.
  #
  def self.pick_hash(attributes, scope: nil)
    scope ||= self
    attributes.keys.zip(scope.pick(*attributes.values)).to_h
  end

  # Sometimes want to execute a generated SQL query that is related to a model,
  # but the return type is so different that we don't want to cast it into any
  # particular ActiveRecord model.
  # This method is similar to exec_query but uses type hints from postgres to
  # cast result values into primitive types
  # @param query [#to_sql] e.g. Arel::SelectManager, ActiveRecord::Relation
  # @return [Array<Hash>]
  def self.exec_query_casted(query)
    # We're intentionally not doing a filter query or an active record query here.
    # The goal is speed and efficiency
    connection_pool.with_connection do |connection|
      connection.exec_query(query.to_sql) => result
      # This is icky. What happens in real rails code is the ActiveRecord::Result
      # object is consumed by ActiveRecord::Base.instantiate which turns takes
      # in rows of untyped results and column types turns them into model objects.
      columns = result.columns.map(&:to_sym)
      result.cast_values.map do |row|
        columns.zip(row).to_h
      end
    end
  end
end
