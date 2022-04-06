# frozen_string_literal: true

# Normalizes values in tzinfo_tz
class CoerceTimezones < ActiveRecord::Migration[7.0]
  def migrate_tzinfo_tz(target_table)
    # execute raw queries - we don't want our models triggering updates or hooks

    # first fetch all rows
    results = ActiveRecord::Base.connection.execute(
      <<~SQL
        SELECT id, tzinfo_tz FROM #{target_table};
      SQL
    )

    # then resolve timezone
    results.each { |row|
      id = row['id']
      old = row['tzinfo_tz']

      case old
      when nil, '' then nil
      # special case the one value we can't automatically infer
      when 'UTC -2' then 'Etc/GMT-2'
      else TimeZoneHelper.to_identifier(row['tzinfo_tz'])
      end => found

      # and then update the values
      value = found.nil? ? 'NULL' : "'#{found}'"
      update_query = <<~SQL
        UPDATE #{target_table}
        SET tzinfo_tz = #{value}
        WHERE id = #{row['id']};
      SQL

      Rails.logger.warn('Data migration executing', id:, old:, found:, update_query:)

      execute(update_query)
    }
  end

  def change
    reversible do |change|
      change.up do
        migrate_tzinfo_tz(:users)
        migrate_tzinfo_tz(:sites)
      end

      change.down do
        Rails.logger.warn(
          'This migration is backwards compatible but does not support reverse migration - no data has been changed'
        )
      end
    end
  end
end
