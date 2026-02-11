# frozen_string_literal: true

module Api
  # Controller concern that streams raw PostgreSQL query results as file downloads.
  # Supports CSV and JSON, both via the COPY protocol. PostgreSQL handles all
  # serialization (CSV natively, JSON via json_build_array) so Ruby does no per-row
  # processing, keeping memory constant regardless of result set size.
  #
  # JSON output uses a columnar format where column names appear once:
  #   {"columns": ["col1", ...], "rows": [[val1, ...], ...]}
  # This avoids repeating column names in every row, reducing output by ~50%.
  #
  # Automatically includes `ActionController::Live` when included.
  #
  # @example
  #   class MyController < ApplicationController
  #     include Api::RawPostgresStreamer
  #
  #     def download
  #       sql = MyModel.some_query.to_sql
  #       stream_query_as_csv(sql, 'my-export')
  #     end
  #   end
  module RawPostgresStreamer
    extend ActiveSupport::Concern

    included do
      # Ensure the including controller has ActionController::Live included
      include ActionController::Live unless included_modules.include?(ActionController::Live)
    end

    private

    # Streams the result of a SQL query as a CSV file download using PostgreSQL's
    # COPY protocol. The response is streamed incrementally so memory usage stays
    # constant regardless of result set size.
    #
    # @param query_sql [String] The SQL query to execute
    # @param filename [String] The base filename (without extension) for the download
    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] The database connection to use
    def stream_query_as_csv(query_sql, filename, connection:)
      filename = "#{filename.trim('.', '')}.csv"

      # Set headers for CSV streaming download
      headers['Cache-Control'] = 'no-cache'
      # Disable buffering for streaming
      headers['X-Accel-Buffering'] = 'no'

      Rails.logger.measure_info('Starting CSV stream') do
        send_stream(filename: filename, type: :csv, disposition: 'attachment') do |stream|
          raw = connection.raw_connection
          raw.copy_data("COPY (#{query_sql}) TO STDOUT WITH CSV HEADER") do
            while (row = raw.get_copy_data)
              stream.write(row)
            end
          end
        end
      end
    end

    # Streams the result of a SQL query as a JSON download using PostgreSQL's
    # COPY protocol with json_build_array.
    #
    # For large result sets, this is much more efficient than building JSON in Ruby.
    # The columnar format reduces output size by ~50% compared to row-based JSON.
    #
    # @param query_sql [String] The SQL query to execute
    # @param filename [String] The base filename (without extension) for the download
    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] The database connection to use
    def stream_query_as_columnar_json(query_sql, filename, connection:)
      filename = "#{filename.trim('.', '')}.json"

      headers['Cache-Control'] = 'no-cache'
      headers['X-Accel-Buffering'] = 'no'

      raw = connection.raw_connection

      # Get column names by executing query with LIMIT 0 (no data fetched)
      column_names = nil
      Rails.logger.measure_info('Fetched column names') do
        columns_result = raw.exec("SELECT * FROM (#{query_sql}) t LIMIT 0")
        column_names = columns_result.fields
      end

      # Build json_build_array with properly quoted column names to preserve order
      columns_sql = column_names.map { |c| "t.#{connection.quote_column_name(c)}" }.join(', ')

      # Stream each row as a JSON array of values
      copy_sql = <<~SQL.squish
        COPY (
          SELECT json_build_array(#{columns_sql})
          FROM (#{query_sql}) t
        )
        TO STDOUT WITH (FORMAT csv, DELIMITER E'\\x01', QUOTE E'\\x02')
      SQL

      Rails.logger.measure_info('Finished JSON stream') do
        send_stream(filename: filename, type: :json, disposition: 'attachment') do |stream|
          # Write header with column names
          stream.write("{\"columns\":#{column_names.to_json},\"rows\":[")

          first = true
          raw.copy_data(copy_sql) do
            while (row = raw.get_copy_data)
              row.chomp!
              if first
                first = false
              else
                stream.write(',')
              end
              stream.write(row)
            end
          end

          stream.write(']}')
        end
      end
    end
  end
end
