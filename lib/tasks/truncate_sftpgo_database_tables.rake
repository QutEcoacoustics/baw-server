# frozen_string_literal: true

namespace :baw do
  desc '❗DESTRUCTIVE❗ Delete all sftpgo database tables. For use when `sftpgo initprovider` is failing.'
  task truncate_sftpgo_tables: :environment do
    def log(message, level = :info)
      indicator = level == :danger ? '❗' : 'ℹ️'

      puts "#{indicator} #{message}"
    end

    log "Environment: #{BawApp.env}"
    log "Database connection: #{ActiveRecord::Base.connection_db_config.inspect}"
    log 'looking for tables'

    tables_query = <<~SQL
      SELECT table_name
      FROM INFORMATION_SCHEMA.TABLES
      WHERE table_name ILIKE 'sftpgo%'
    SQL

    tables = ActiveRecord::Base.connection.exec_query(tables_query).map(&:first).map(&:second)

    if tables.count.zero?
      log 'No sftpgo tables found, nothing to do, exiting'
      exit 0
    end

    log "Found tables: #{tables}"

    truncation = tables.map { |table_name|
      <<~SQL
        DROP TABLE IF EXISTS #{table_name} CASCADE;
      SQL
    }.join("\n  ")
    transaction_query = <<~SQL
      BEGIN;
        #{truncation}
      COMMIT;
    SQL

    log "about to truncate tables with query:\n#{transaction_query}", :danger
    log 'are you sure?', :danger

    answer = $stdin.gets.chomp
    unless answer == 'y'
      log "input was not exactly 'y', exiting"
      exit 1
    end

    result = ActiveRecord::Base.connection.execute(transaction_query)
    log 'tables truncated, results:', :danger
    puts result.inspect

    log 'Ensure you restart sftpgo services', :danger
  end
end
