# frozen_string_literal: true

require 'active_support/concern'

module Filter
  # Provides custom filters for composing queries.
  module Custom
    extend ActiveSupport::Concern
    extend Comparison
    extend Core
    extend Subset
    extend Validate

    private

    # Create SIMILAR TO condition for text.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] text_allowed
    # @param [Array<String>] text_array
    # @return [Arel::Nodes::Node] condition
    def compose_similar(table, column_name, text_allowed, text_array)
      #tags_partial = CSV.parse(params[:tagsPartial], col_sep: ',').flatten.map { |item| item.trim(' ', '') }.join('|').downcase
      #tags_query = AudioEvent.joins(:tags).where('lower(tags.text) SIMILAR TO ?', "%(#{tags_partial})%").select('audio_events.id')

      validate_table_column(table, column_name, text_allowed)
      validate_array(text_array)
      validate_array_items(text_array)
      sanitized_value = text_array.map { |item| sanitize_similar_to_value(item.trim(' ', '')) }.join('|').downcase
      contains_value = "%(#{sanitized_value})%"
      lower_value = "lower(#{table.name}.#{column_name})"
      similar = "#{lower_value} SIMILAR TO #{contains_value}"

      Arel::Nodes::SqlLiteral.new(similar)
    end

    # Create distance projection.
    # @param [Float] freq_min
    # @param [Float] freq_max
    # @param [Float] annotation_duration
    # @return [Arel::Nodes::Node] projection
    def project_distance(freq_min, freq_max, annotation_duration)
      if !freq_min.blank? || !freq_max.blank? || !annotation_duration.blank?
        select_string = []

        unless freq_min.blank?
          validate_float(freq_min)
          select_string.push("power(audio_events.low_frequency_hertz - #{freq_min}, 2)")
        end

        unless freq_max.blank?
          validate_float(freq_max)
          select_string.push("power(audio_events.high_frequency_hertz - #{freq_max}, 2)")
        end

        unless annotation_duration.blank?
          validate_float(annotation_duration)
          select_string.push("power((audio_events.end_time_seconds - audio_events.start_time_seconds) - #{annotation_duration}, 2)")
        end

        sql = 'sqrt(' + select_string.join(' + ') + ') as distance_calc'

        Arel::Nodes::SqlLiteral.new(sql)
      end
    end

    # Compose special project ids 'in' filter.
    # @param [Symbol] field
    # @param [Symbol] filter_name
    # @param [Object] filter_value
    # @param [Arel::Table] table
    # @param [Array<Symbol>] valid_fields
    # @return [Arel::Nodes::Node] condition
    def compose_sites_from_projects(field, filter_name, filter_value, table, valid_fields)
      # construct special conditions
      if table.name == 'sites' && field == :project_ids
        # filter by many-to-many projects <-> sites
        unless filter_name == :in
          raise CustomErrors::FilterArgumentError, "Project_ids permits only 'in' filter, got #{filter_name}."
        end

        projects_sites_table = Arel::Table.new(:projects_sites)
        special_value = Arel::Table.new(:projects_sites).project(:site_id).where(compose_in(projects_sites_table, :project_id, [:project_id], filter_value))
        compose_in(table, :id, valid_fields, special_value)
      end
    end
  end
end
