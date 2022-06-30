# frozen_string_literal: true

module Api
  # Helpers for working with CSV in API requests
  module Csv
    module_function

    def dump(data)
      headers = data.reduce(Set.new) { |prev, current| prev + current.keys }.to_a

      CSV.generate(
        write_headers: true,
        headers:,
        force_quotes: true
      ) do |csv|
        data.each do |row|
          csv << row.fetch_values(*headers) { |_| nil }
        end
      end
    end
  end
end
