# frozen_string_literal: true

# ! author: GitLab B.V.
# ! license MIT Expat https://gitlab.com/gitlab-org/gitlab/-/blob/f81fa6ab1dd788b70ef44b85aaba1f31ffafae7d/LICENSE
# ! https://gitlab.com/gitlab-org/gitlab/-/blob/7d6547ce36361ef056e76e02d21f409e4b728ba6/spec/support/helpers/migrations_helpers.rb

require 'find'

# https://gitlab.com/gitlab-org/gitlab/-/blob/7d6547ce36361ef056e76e02d21f409e4b728ba6/spec/support/helpers/require_migration.rb
class RequireMigration
  class AutoLoadError < RuntimeError
    MESSAGE = "Can not find any migration file for `%<file_name>s`!\n" \
              'You can try to provide the migration file name manually.'

    def initialize(file_name)
      message = format(MESSAGE, file_name:)

      super(message)
    end
  end

  MIGRATION_FOLDERS = ['db/migrate'].freeze
  SPEC_FILE_PATTERN = %r{.+/(?:\d+_)?(?<file_name>.+)_spec\.rb}

  class << self
    def require_migration!(file_name)
      file_paths = search_migration_file(file_name)
      raise AutoLoadError, file_name unless file_paths.first

      require file_paths.first
    end

    def search_migration_file(file_name)
      migration_file_pattern = /\A\d+_#{file_name}\.rb\z/

      migration_folders.flat_map do |path|
        migration_path = Rails.root.join(path).to_s

        Find.find(migration_path).select { |manager| migration_file_pattern.match? File.basename(manager) }
      end
    end

    private

    def migration_folders
      MIGRATION_FOLDERS
    end
  end
end

def require_migration!(file_name = nil)
  location_info = caller_locations.first.path.match(RequireMigration::SPEC_FILE_PATTERN)
  file_name ||= location_info[:file_name]

  RequireMigration.require_migration!(file_name)
end

module MigrationsHelpers
  def active_record_base
    ActiveRecord::Base
  end

  def table(name)
    Class.new(active_record_base) do
      self.table_name = name
      self.inheritance_column = :_type_disabled

      def self.name
        table_name.singularize.camelcase
      end

      yield self if block_given?
    end
  end

  def migrations_paths
    active_record_base.connection_pool.migrations_paths
  end

  def migration_context
    ActiveRecord::MigrationContext.new(migrations_paths)
  end

  delegate :migrations, to: :migration_context

  def clear_schema_cache!
    active_record_base.connection_pool.connections.each do |conn|
      conn.schema_cache.clear!
    end
  end

  def foreign_key_exists?(source, target = nil, column: nil)
    active_record_base.connection.foreign_keys(source).any? do |key|
      if column
        key.options[:column].to_s == column.to_s
      else
        key.to_table.to_s == target.to_s
      end
    end
  end

  def reset_column_in_all_models
    clear_schema_cache!

    # Reset column information for the most offending classes **after** we
    # migrated the schema up, otherwise, column information could be
    # outdated. We have a separate method for this so we can override it in EE.
    active_record_base.descendants.each(&method(:reset_column_information))
  end

  def refresh_attribute_methods
    # Without this, we get errors because of missing attributes, e.g.
    # super: no superclass method `elasticsearch_indexing' for #<ApplicationSetting:0x00007f85628508d8>
    # attr_encrypted also expects ActiveRecord attribute methods to be
    # defined, or it will override the accessors:
    # https://gitlab.com/gitlab-org/gitlab/issues/8234#note_113976421
    #[ApplicationSetting, SystemHook].each(&:define_attribute_methods)
  end

  def reset_column_information(klass)
    klass.reset_column_information
  end

  # In some migration tests, we're using factories to create records,
  # however those models might be depending on a schema version which
  # doesn't have the columns we want in application_settings.
  # In these cases, we'll need to use the fake application settings
  # as if we have migrations pending
  def use_fake_application_settings
    # We stub this way because we can't stub on
    # `current_application_settings` due to `method_missing` is
    # depending on current_application_settings...
    allow(ActiveRecord::Base.connection)
      .to receive(:active?)
      .and_return(false)
  end

  def previous_migration(steps_back = 2)
    migrations.each_cons(steps_back) do |cons|
      break cons.first if cons.last.name == described_class.name
    end
  end

  def migration_schema_version
    metadata_schema = self.class.metadata[:schema]

    if metadata_schema == :latest
      migrations.last.version
    else
      metadata_schema || previous_migration.version
    end
  end

  def schema_migrate_down!
    disable_migrations_output do
      version = migration_schema_version
      logger.info('migrating database down!', to_version: version)
      migration_context.down(version)
    rescue StandardError => e
      logger.error("Failed to migrate down to version #{version}", error: e)
      raise
    end

    reset_column_in_all_models
  end

  def schema_migrate_up!
    reset_column_in_all_models

    disable_migrations_output do
      logger.info('migrating database up!')
      migration_context.up
    end

    reset_column_in_all_models
    refresh_attribute_methods
  end

  def disable_migrations_output
    ActiveRecord::Migration.verbose = false

    yield
  ensure
    ActiveRecord::Migration.verbose = true
  end

  def migrate!
    migration_context.up do |migration|
      migration.name == described_class.name
    end
  end

  class ReversibleMigrationTest
    attr_reader :before_up, :after_up

    def initialize
      @before_up = -> {}
      @after_up = -> {}
    end

    def before(expectations)
      @before_up = expectations

      self
    end

    def after(expectations)
      @after_up = expectations

      self
    end
  end

  def reversible_migration
    tests = yield(ReversibleMigrationTest.new)

    tests.before_up.call

    migrate!

    tests.after_up.call

    schema_migrate_down!

    tests.before_up.call
  end
end

# https://gitlab.com/gitlab-org/gitlab/-/blob/7d6547ce36361ef056e76e02d21f409e4b728ba6/spec/support/migration.rb
RSpec.configure do |config|
  # The :each scope runs "inside" the example, so this hook ensures the DB is in the
  # correct state before any examples' before hooks are called. This prevents a
  # problem where `ScheduleIssuesClosedAtTypeChange` (or any migration that depends
  # on background migrations being run inline during test setup) can be broken by
  # altering Sidekiq behavior in an unrelated spec like so:
  #
  # around do |example|
  #   Sidekiq::Testing.fake! do
  #     example.run
  #   end
  # end
  config.before(:context, :migration) do
    schema_migrate_down!
  end

  # Each example may call `migrate!`, so we must ensure we are migrated down every time
  config.before(:each, :migration) do
    use_fake_application_settings

    schema_migrate_down!
  end

  config.after(:context, :migration) do
    schema_migrate_up!
  end
end
