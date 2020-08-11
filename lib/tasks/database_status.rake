# frozen_string_literal: true

def __baw_db_log(message)
  puts "\n🕵️ #{message}\n"
end

def __baw_db_status
  result = -1
  begin
    # Tries to initialize the application.
    # It will fail if the database does not exist
    Rake::Task['environment'].invoke

    # let the script know if migrations are needed
    migrations_paths = ActiveRecord::Migrator.migrations_paths
    schema_migration = ActiveRecord::Base.connection.schema_migration
    migration_context = ActiveRecord::MigrationContext.new(migrations_paths, schema_migration)
    if migration_context.needs_migration?
      __baw_db_log 'ℹ Database needs to be migrated'
      result = 2
    else
      __baw_db_log '✔ Database is ready'
      result = 0
    end
  rescue ActiveRecord::NoDatabaseError
    __baw_db_log 'ℹ Database needs to be created'
    result = 1
  rescue StandardError => e
    __baw_db_log '❌ Failed to check database status'
    puts e.message
    e.backtrace.each { |line| puts line }

    exit 255
  end

  result
end

namespace :baw do
  desc 'Cancel database check if MIGRATE_DB=false'
  task :skip_check? do
    __baw_db_log "❔ Should we skip check? MIGRATE_DB is `#{ENV['MIGRATE_DB']}`"
    if ENV['MIGRATE_DB'] != 'true'
      __baw_db_log '⏭ Skipping database status checks because MIGRATE_DB is not exactly `true`'
      exit 0
    else
      __baw_db_log '⭐ We should not skip; continuing...'
    end
  end

  desc 'Check an environment is set'
  task :check_env do
    if ENV['RAILS_ENV'].blank?
      __baw_db_log '❌ Fail: The RAILS_ENV environment variable must be set!'
      exit 1
    end
  end

  desc 'Checks whether the database exists or not'
  task db_status: :check_env do
    exit __baw_db_status
  end

  desc 'migrate alias'
  task db_migrate: ['db:migrate', 'db:seed']

  desc 'setup alias'
  task db_setup: ['db:setup']

  desc 'Migrate or create database'
  task db_prepare: [:skip_check?, :check_env] do
    __baw_db_log "ℹ Checking database status for #{ENV['RAILS_ENV']}"

    case __baw_db_status
    when 0
      exit 0
    when 1
      __baw_db_log 'ℹ Creating database'
      Rake::Task['baw:db_setup'].invoke
      __baw_db_log '✔ Database is ready'
      exit 0
    when 2
      __baw_db_log 'ℹ Migrating database'
      Rake::Task['baw:db_migrate'].invoke
      __baw_db_log '✔ Database is ready'
      exit 0
    else
      __baw_db_log '❌ failed to prepare database'
      exit 1
    end
  end
end
