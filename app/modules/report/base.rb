# frozen_string_literal: true

module Report
  extend ActiveSupport::Concern

  class Base
    def initialize(filter_params, base_scope)
      @filter_params = filter_params
      @base_scope = base_scope
      parse_parameters(filter_params, base_scope)
    end

    def generate
      query = build_query
      results = execute(query)
      format_results(results)
    end

    private

    # Parse the filter parameters into a hash and generate the base query
    # @return [Hash] the parsed parameters
    def parse_parameters(filter_params, base_scope)
      parameters = filter_params_to_hash(filter_params)
      filtered_base_query = filter_as_relation(parameters, base_scope)

      @base_query = filtered_base_query
      @parameters = parameters
    end

    # Default implementation for building the query
    # @return [Arel::SelectManager] the query object
    # @raise [NotImplementedError] if not implemented
    def build_query
      raise NotImplementedError, 'missing implementation'
    end

    # Default implementation for executing the query
    # @param query [Arel::SelectManager] the query object
    # @return [ActiveRecord::Result] the result of the query
    def execute(query)
      ActiveRecord::Base.connection.execute(query.to_sql)
    end

    # Default implementation for formatting the results as JSON
    # @param results [ActiveRecord::Result] the result of the query
    # @return [Hash] the formatted results
    def format_results(results)
      results.as_json
    end

    # Default implementation for applying filters to get the base query
    # @return [Arel::SelectManager] query with filters applied
    # @raise [NotImplementedError] if not implemented
    def filter_as_relation(parameters, base_scope)
      raise NotImplementedError, 'missing implementation'
    end

    def filter_params_to_hash(params)
      params = params.to_h if params.is_a? ActionController::Parameters
      return params if params.is_a? ActiveSupport::HashWithIndifferentAccess

      raise ArgumentError,
        'params needs to be HashWithIndifferentAccess' \
        'or an ActionController::Parameters'
    end
  end
end
