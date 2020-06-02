# frozen_string_literal: true

namespace :db do
  desc 'Checks whether the database exists or not'
  task :status do
    begin
      # Tries to initialize the application.
      # It will fail if the database does not exist
      Rake::Task['environment'].invoke
      connection = ActiveRecord::Base.connection

      # let the script know if migrations are needed
      exit 2 if ActiveRecord::Migrator.needs_migration?(connection)
    rescue ActiveRecord::NoDatabaseError
      exit 1
    rescue StandardError => e
      puts e.message
      e.backtrace.each { |line| puts line }

      exit 255
    else
      exit 0
    end
  end
end
