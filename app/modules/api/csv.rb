# frozen_string_literal: true

module Api
  # Helpers for working with CSV in API requests
  module Csv
    STANDARD_ACCESSOR = ->(key, row) { row.fetch(key).as_json }

    module_function

    def dump(data)
      return '' if data.blank?

      headers = []
      accessors = []

      # Single pass over the first row to build column headers and value accessors.
      # Range values are expanded into two columns: key_lower and key_upper.
      # Values are formatted via as_json for consistent API-wide serialization.
      data.first.each do |key, sample|
        case sample
        in ::Range
          headers << "#{key}_lower"
          headers << "#{key}_upper"
          accessors << ->(row) { row[key]&.begin&.as_json }
          accessors << ->(row) { row[key]&.end&.as_json }
        else
          headers << key.to_s
          accessors << STANDARD_ACCESSOR.curry[key]
        end
      end

      CSV.generate(
        write_headers: true,
        headers:,
        force_quotes: true
      ) do |csv|
        data.each do |row|
          csv << accessors.map { |a| a.call(row) }
        end
      end
    end
  end
end
