require 'csv'

# run using rake baw:import:annotations['csv file']
namespace :baw do
  namespace :import do

    desc 'Import annotations from a csv file.'
    task :annotations, [:csv_file] do |t, args|

      csv_headers = {
          species_name: 0,
          max_frequency: 1,
          min_frequency: 2,
          start_time: 3,
          end_time: 4,
          absolute_date_plus_10: 5,
          site_id: 6,
          project_id: 7
      }

      audio_event_headers = [
          :audio_recording_id,
          :start_time_seconds,
          :end_time_seconds,
          :low_frequency_hertz,
          :high_frequency_hertz,
          :is_reference,
          :creator_id,
          :updater_id,
          :deleter_id,
          :deleted_at,
          :created_at,
          :updated_at
      ]

      audio_events_tags_headers = [
          :audio_event_id,
          :tag_id,
          :created_at,
          :updated_at,
          :creator_id,
          :updater_id
      ]

      # load csv file
      CSV.foreach(args.csv_file, {headers: true, return_headers: false}) do |row|

        # get values from row, put into hash that matches what is expected
        audio_event_params = csv_headers.inject({}) do |hash, (k, v)|
          hash.merge(k.to_sym => row[k.to_s])
        end

        audio_events_tags_params = {}
        
        # provide the parameters to yield
        yield audio_event_params, audio_events_tags_params if block_given?
      end

    end

  end
end