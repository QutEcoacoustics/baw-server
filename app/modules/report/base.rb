# frozen_string_literal: true

module Report
  extend ActiveSupport::Concern
  #
  # Base class for building reports.
  #
  # Concrete implementations can define a default #filter_as_relation method and
  # an array of default sections. However, these can be overriden by passing in
  # the required arguments when initializing an object < Report::Base.
  #
  # @example when subclassing
  #   class SomeReport < Report::Base
  #     SECTIONS = [Report::Section::Something]
  #
  #     def filter_as_relation(filter_params, base_scope)
  #       # custom implementation
  #     end
  #   end
  #   report = SomeReport.new(api_filter_params, base_scope)
  #
  # @ example when using the base class directly
  #   report = Report::Base.new(
  #     api_filter_params,
  #     base_scope,
  #     Filter::Query.new( ... ),
  #     [Report::Section::Something]
  #   )
  class Base
    # @return [Array<Class>] the Report::Section classes to be used in the report
    SECTIONS = [].freeze

    # @param [Hash] filter_params the filter parameters for the report
    # @param [ActiveRecord::Relation] base_scope with user permissions applied.
    # @param [ActiveRecord::Relation] filter_as_relation an optional relation to
    #   use as the report's filtered base query.
    # @param [Array<Class>] sections an optional Array of Report::Section classes
    def initialize(filter_params, base_scope, filter_as_relation = nil, sections = nil, options = {})
      @parameters = filter_params_to_hash(filter_params)
      @base_query = filter_as_relation || filter_as_relation(@parameters, base_scope)
      @sections = instantiate_sections(sections || self.class::SECTIONS)
      @options = options
    end

    # @return [Hash] the parameters for the report
    attr_reader :parameters

    # @return [] the base query for the report
    attr_reader :base_query

    # @return [Array<Report::Section>] instantiated sections
    attr_reader :sections

    # TODO: merge with parameters?
    # @return [Hash] options needed for the report sections
    attr_reader :options

    attr_accessor :base_table, :base_cte

    def generate
      query = base_query.arel.project(attributes)
      query = joins.call(query)

      @base_table = Arel::Table.new('base_table')
      @base_cte = Arel::Nodes::As.new(base_table, query)
      query = prepare

      results = execute(query)
      format_results(results)
    end

    private

    # default attributes to .project onto the base query
    # @return [Array<Arel::Attributes>] the attributes to select
    def attributes
      []
    end

    # add joins to the query
    # @param query [Arel::SelectManager] the query object
    # @return [Arel::SelectManager] the query object with joins added
    def joins(query)
      query
    end

    # Default implementation for building the query
    # @return [Arel::SelectManager] the query object
    # @raise [NotImplementedError] if not implemented
    def build_query
      # base_query_projected = base.arel.project(attributes)
      # base_query_joined = add_joins(base_query_projected)
      # base_table = Arel::Table.new('base_table')
      # Arel::Nodes::As.new(base_table, base_query_joined)
      # raise NotImplementedError, 'missing implementation'
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
      raise NotImplementedError, 'missing implementation'
    end

    # The base query for a report is a filter query, which has user permissions
    # and any filter parameters applied.
    #
    # @note
    #   Existing response logic for filter requests is model-centric (see
    #   Api::Response#response). However, a report is not backed by a database
    #   model, so some required logic is extracted into the methods
    #   {#filter_as_relation} and {#filter_params_to_hash}.
    #
    # @return [ActiveRecord::Relation] the base query with filters applied
    def filter_as_relation(filter_params, base_scope)
      raise NotImplementedError, 'missing implementation'
    end

    # Normalise filter parameters, extracted from Api::Response#response
    # @param params [Hash]
    # @return [HashWithIndifferentAccess]
    def filter_params_to_hash(params)
      params = params.to_h if params.is_a? ActionController::Parameters
      return params if params.is_a? ActiveSupport::HashWithIndifferentAccess

      raise ArgumentError,
        'params needs to be HashWithIndifferentAccess' \
        'or an ActionController::Parameters'
    end

    # Instantiate the sections for the report
    def instantiate_sections(sections)
      raise ArgumentError, 'sections must be an Array' unless sections.is_a?(Array)
      raise ArgumentError, 'at least one section is required' if sections.empty?

      # raise ArgumentError, 'all sections must be subclasses of Report::Section' unless sections.all? { |s|
      #   s.is_a?(Class) && s < Report::Section
      # }

      # sections.map { |section_class| section_class.new(options) }
    end
  end
end
