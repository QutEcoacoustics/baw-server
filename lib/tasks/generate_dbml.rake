# frozen_string_literal: true

require 'English'
namespace :baw do
  task set_schema_format: :environment do
    ActiveRecord.schema_format = :ruby
  end

  desc 'Generate a DBML file from the database schema'
  task generate_dbml: [:set_schema_format, 'db:schema:dump'] do
    require 'schema_to_dbml'
    # Load configuration from default file
    SchemaToDbml.configuration.custom_dbml_file_path = 'db/schema.dbml'

    # This will generate the file (db/schema.dbml) with the above content
    SchemaToDbml.new.generate(schema: 'db/schema.rb')
  end

  task delete_ruby_schema_dump: :environment do
    File.delete('db/schema.rb')
  end

  Rake::Task['baw:generate_dbml'].enhance do
    #Rake::Task['baw:delete_ruby_schema_dump'].invoke
  end
end
