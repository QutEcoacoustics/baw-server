module AlphabeticalPaginatorQuery
  OTHER = "\u{1F30F}"
  NUMBERS = '0-9'

  extend ActiveSupport::Concern

  class_methods do

    def alphabetical_page(field, range)
      range = 'a-b' if range.blank?
      left, right = range.split('-')
      query_type = validate_range(left, right)

      if query_type == :normal
        if left == right then
          q = where(["LOWER(LEFT(\"#{field.to_s}\", ?)) = ?",
                     left.length,
                     left
                    ])
        else
          q = where(["LOWER(LEFT(\"#{field.to_s}\", ?)) >= ? AND LOWER(LEFT(\"#{field.to_s}\", ?)) <= ?",
                     left.length,
                     left,
                     right.length,
                     right
                    ])
        end
      elsif query_type == :numbers
        q = where(["\"#{field.to_s}\" ~ '^\\d+'", field])
      else
        q = where(["\"#{field.to_s}\" !~ '^[a-zA-Z0-9]'", field])
      end


      q.order(field)
    end

    private

    def validate_range(left, right)
      return :other if OTHER == left && right.blank?
      return :numbers if left == '0' && right == '9'

      return :normal if /^[a-z]+$/ =~ left && /^[a-z]+$/ =~ right

      fail ArgumentError, 'Alphabetical paginator range invalid'
    end

  end

end


ActiveRecord::Base.send(:include, AlphabeticalPaginatorQuery)