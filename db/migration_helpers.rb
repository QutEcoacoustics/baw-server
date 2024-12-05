# frozen_string_literal: true

# Reusable widgets for migrations.
# Include this module in your migration to use these helpers.
module MigrationsHelpers
  # Add a primary key to one or more columns
  # @param [Symbol] table
  # @param [Array<Symbol>] columns
  def alter_primary_key_constraint(table, columns)
    name = "#{table}_pkey"
    cols = columns.join(', ')
    reversible do |change|
      change.up do
        query = <<~SQL.squish
          ALTER TABLE #{table} ADD CONSTRAINT #{name} PRIMARY KEY (#{cols});
        SQL

        execute(query)
      end
      change.down do
        query = <<~SQL.squish
          ALTER TABLE #{table} DROP CONSTRAINT IF EXISTS #{name};
        SQL

        execute(query)
      end
    end
  end

  # Modify an existing foreign key to enable or disable ON DELETE CASCADE
  # @param foreign_key [ActiveRecord::ConnectionAdapters::ForeignKeyDefinition]
  # @param on_delete_cascade [Boolean] if `true`, enable ON DELETE CASCADE,
  #   else sets it to NO ACTION
  def alter_foreign_key_cascade(foreign_key, on_delete_cascade:)
    unless foreign_key.is_a?(ActiveRecord::ConnectionAdapters::ForeignKeyDefinition)
      raise ArgumentError,
        'foreign_key must be a ActiveRecord::ConnectionAdapters::ForeignKeyDefinition'
    end

    foreign_key => {from_table:, to_table:, options: }

    reversible do |change|
      change.up do
        options[:on_delete] = :cascade if on_delete_cascade
        options.delete(:on_delete) unless on_delete_cascade

        remove_foreign_key(from_table, to_table)
        add_foreign_key(from_table, to_table, **options)
      end
      change.down do
        # down reverses the preference of on_delete_cascade
        options[:on_delete] = :cascade unless on_delete_cascade
        options.delete(:on_delete) if on_delete_cascade

        remove_foreign_key(from_table, to_table, if_exists: true)
        add_foreign_key(from_table, to_table, **options)
      end
    end
  end

  def get_foreign_key(from_table, column)
    foreign_keys(from_table).find do |fk|
      fk.column == column.to_s
    end || raise(ArgumentError, "No foreign key found for #{from_table}.#{column}")
  end
end
