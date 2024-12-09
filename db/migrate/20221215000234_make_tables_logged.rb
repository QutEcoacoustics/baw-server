# frozen_string_literal: true

# https://github.com/QutEcoacoustics/baw-server/issues/635
class MakeTablesLogged < ActiveRecord::Migration[7.0]
  def alter_logged(table, logged: tue)
    query = <<~SQL
      ALTER TABLE #{table} SET #{logged ? 'LOGGED' : 'UNLOGGED'};
    SQL

    execute(query)
  end

  def change
    reversible do |change|
      change.up do
        alter_logged(:user_statistics, logged: true)
        alter_logged(:anonymous_user_statistics, logged: true)
        alter_logged(:audio_recording_statistics, logged: true)
      end
      change.down do
        alter_logged(:user_statistics, logged: false)
        alter_logged(:anonymous_user_statistics, logged: false)
        alter_logged(:audio_recording_statistics, logged: false)
      end
    end
  end
end
