# frozen_string_literal: true

module AlphabeticalPaginatorQuery
  OTHER = "\u{1F30F}"
  NUMBERS = '0-9'

  extend ActiveSupport::Concern

  class_methods do

    def alphabetical_page(field, range)
      range = 'a-b' if range.blank?
      left, right = range.split('-')
      query_type = validate_range(left, right)

      q = if query_type == :normal
            if left == right
              where(["LOWER(LEFT(\"#{field}\", ?)) = ?",
                     left.length,
                     left])
            else
              where(["LOWER(LEFT(\"#{field}\", ?)) >= ? AND LOWER(LEFT(\"#{field}\", ?)) <= ?",
                     left.length,
                     left,
                     right.length,
                     right])
                end
          elsif query_type == :numbers
            where(["\"#{field}\" ~ '^\\d+'", field])
          else
            where(["\"#{field}\" !~ '^[a-zA-Z0-9]'", field])
          end

      q.order(field)
    end

    private

    def validate_range(left, right)
      return :other if OTHER == left && right.blank?
      return :numbers if left == '0' && right == '9'

      return :normal if /^[a-z]+$/ =~ left && /^[a-z]+$/ =~ right

      raise ArgumentError, 'Alphabetical paginator range invalid'
    end

  end
end
