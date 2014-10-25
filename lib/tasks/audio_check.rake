namespace :baw do
  namespace :action do
    namespace :audio_check do
      namespace :resque do

        desc 'Enqueue audio recording file checks from a csv file to be processed using Resque worker'
        task :from_csv, [:settings_file] => ['worker:init_redis'] do |t, args|

          # read csv
          csv_file = BawWorkers::Settings.actions.audio_check.to_do_csv_path

          # enqueue files to be processed by resque
          BawWorkers::AudioCheck::CsvHelper.read_audio_recording_csv(csv_file) do |audio_params|
            BawWorkers::AudioCheck::Action.action_enqueue(audio_params)
          end

        end

      end

      namespace :standalone do

        desc 'Enqueue audio recording file checks from a csv file to be processed using Resque worker'
        task :from_csv, [:settings_file] => ['worker:init_settings'] do |t, args|

          # read csv
          csv_file = BawWorkers::Settings.actions.audio_check.to_do_csv_path

          # process all files from csv right now
          BawWorkers::AudioCheck::CsvHelper.read_audio_recording_csv(csv_file) do |audio_params|
            BawWorkers::AudioCheck::Action.action_perform(audio_params)
          end
        end

      end

    end
  end
end