# frozen_string_literal: true

module Filter
  # Provides support for including archived records in a query.
  module Archivable
    extend ActiveSupport::Concern

    # @return [Boolean] whether to include archived records in the query
    attr_accessor :with_archived

    private

    def set_archived_param(params)
      @with_archived = params[::Api::Archivable::ARCHIVE_ACCESS_PARAM] == true
    end

    # Add a condition to the query to include archived records.
    # @param [ActiveRecord::Relation] query
    # @return [ActiveRecord::Relation] query
    def query_with_archived_if_appropriate(query)
      return query unless @model.discardable?

      return query.with_discarded if with_archived

      query
    end
  end
end
