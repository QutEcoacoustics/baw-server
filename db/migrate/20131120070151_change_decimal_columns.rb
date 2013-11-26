class ChangeDecimalColumns < ActiveRecord::Migration
  def up
    # http://stackoverflow.com/questions/1196415/what-datatype-to-use-when-storing-latitude-and-longitude-data-in-sql-databases
    # http://en.wikipedia.org/wiki/Wikipedia:WikiProject_Geographical_coordinates#Precision
    # accurate up to 11cm ( ###.###### )
    change_column :sites, :longitude, :decimal, precision: 9, scale: 6
    change_column :sites, :latitude, :decimal, precision: 9, scale: 6

    # store to fractions of milliseconds accuracy ( ######.#### ), up to 1 million seconds
    change_column :bookmarks, :offset_seconds, :decimal, precision: 10, scale: 4
    change_column :audio_recordings, :duration_seconds, :decimal, precision: 10, scale: 4
    change_column :audio_events, :start_time_seconds, :decimal,  precision: 10, scale: 4
    change_column :audio_events, :end_time_seconds, :decimal, precision: 10, scale: 4

    # store to fractions of millihertz accuracy ( ######.#### ), up to 1 million hertz (e.g. bats at 300,000 hertz)
    change_column :audio_events, :low_frequency_hertz, :decimal, precision: 10, scale: 4
    change_column :audio_events, :high_frequency_hertz, :decimal, precision: 10, scale: 4

  end

  def down
    change_column :sites, :longitude, :decimal
    change_column :sites, :latitude, :decimal

    change_column :bookmarks, :offset_seconds, :decimal
    change_column :audio_recordings, :duration_seconds, :decimal
    change_column :audio_events, :start_time_seconds, :decimal
    change_column :audio_events, :end_time_seconds, :decimal

    change_column :audio_events, :low_frequency_hertz, :decimal
    change_column :audio_events, :high_frequency_hertz, :decimal
  end
end
