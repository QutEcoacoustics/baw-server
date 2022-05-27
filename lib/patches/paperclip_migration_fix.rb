# frozen_string_literal: true

# fix bug in paperclip attachment migration
# https://github.com/thoughtbot/paperclip/issues/2698
require 'paperclip'
module Paperclip
  module Schema
    module TableDefinition
      def attachment(*attachment_names)
        options = attachment_names.extract_options!
        attachment_names.each do |attachment_name|
          COLUMNS.each_pair do |column_name, column_type|
            column_options = options.merge(options[column_name.to_sym] || {})
            column("#{attachment_name}_#{column_name}", column_type, *column_options)
          end
        end
      end
    end

    module Statements
      def add_attachment(table_name, *attachment_names)
        if attachment_names.empty?
          raise ArgumentError,
            'Please specify attachment name in your add_attachment call in your migration.'
        end

        options = attachment_names.extract_options!

        attachment_names.each do |attachment_name|
          COLUMNS.each_pair do |column_name, column_type|
            column_options = options.merge(options[column_name.to_sym] || {})
            add_column(table_name, "#{attachment_name}_#{column_name}", column_type, **column_options)
          end
        end
      end
    end
  end
end
