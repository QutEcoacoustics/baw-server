# frozen_string_literal: true

namespace :db do
  desc 'Checks whether the database exists or not'
  task :status do
    begin
    # Tries to initialize the application.
    # It will fail if the database does not exist
    Rake::Task['environment'].invoke
    ActiveRecord::Base.connection

    # let the script know if migrations are needed
    return 2 unless ActiveRecord::Migrator.get_all_versions.empty?
    rescue StandardError
      exit 1
    else
      exit 0
    end
  end
end
