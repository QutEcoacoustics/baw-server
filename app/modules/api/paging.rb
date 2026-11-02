# frozen_string_literal: true

module Api
  module Paging
    TOTAL_COUNT_COLUMN = '__baw_api_total_count'

    # Included into ActiveRecord::Relation by Baw::Patch.apply.
    module RelationMethods
      # Add a total count column to the relation for paging purposes.
      #
      # @param opts [Hash] the options hash for a filter query
      # @return [ActiveRecord::Relation] a new relation, extended with the TotalCount module.
      def with_paging_total(opts)
        relation = select(Arel.star.count.over(Arel::Nodes::Window.new).as(TOTAL_COUNT_COLUMN)).extending(TotalCount)
        relation.instance_variable_set(:@paging_opts, opts)
        relation
      end
    end

    # Extended onto a relation by with_paging_total to read the total count when records load.
    module TotalCount
      attr_reader :paging_opts

      private

      # Filter::Query#query_paging applies no limit when paging is disabled. In that case,
      # the number of items in paging_opts[:items] should equal the total.
      def instantiate_records(rows, &)
        paging_opts[:total] = rows.empty? ? count_without_paging : count_from_rows(rows)
        paging_opts[:items] = paging_opts[:total] if limit_value.nil?
        super(without_total_column(rows), &)
      end

      # An empty page has no row to read the total from. No offset signals a genuine zero row result.
      # Otherwise, we don't know, and need to query again for size.
      def count_without_paging
        return 0 if offset_value.to_i.zero?

        total = Rails.logger.measure_warn('Paging ran an extra count query because the page is past the last row') {
          unscope(:limit, :offset).size
        }

        # An aggregation query returns a hash, so return the number of groups.
        total.is_a?(Hash) ? total.length : total
      end

      def count_from_rows(rows)
        rows.rows.first[rows.columns.index(TOTAL_COUNT_COLUMN)]
      end

      def without_total_column(rows)
        return rows if rows.empty?
        unless rows.columns.last == TOTAL_COUNT_COLUMN
          raise ArgumentError, "#{TOTAL_COUNT_COLUMN} must be the last selected column"
        end

        # Create a new ActiveRecord::Result without the total count column. The
        # new result uses the same rows object, so no memory is spent recreating
        # the row data.
        ActiveRecord::Result.new(rows.columns[0...-1], rows.rows, rows.column_types)
      end
    end
  end
end
