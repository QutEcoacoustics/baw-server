require 'csv'

namespace :baw do
  namespace :action do
    namespace :audio_check do
      namespace :resque do

        desc 'Enqueue audio recording file checks from a csv file to be processed using Resque worker'
        task :from_csv, [:settings_file] => ['worker:init_redis'] do |t, args|

          index_to_key_map = {
              id: 0,
              uuid: 1,
              recorded_date: 2,
              duration_seconds: 3,
              sample_rate_hertz: 4,
              channels: 5,
              bit_rate_bps: 6,
              media_type: 7,
              data_length_bytes: 8,
              file_hash: 9,
              original_file_name: 10
          }

          # load csv file
          CSV.foreach(args.csv_file, {headers: true, return_headers: false}) do |row|

            # get values from row, put into hash that matches what check action expects
            audio_params = index_to_key_map.inject({}) do |hash, (k, v)|
              hash.merge(k.to_sym => row[k.to_s])
            end

            # special case for original_format
            # get original_format from original_file_name
            original_file_name = audio_params.delete(:original_file_name)
            original_extension = original_file_name.blank? ? '' : File.extname(original_file_name).trim('.', '').downcase
            audio_params[:original_format] = original_extension

            # get extension from media_type
            audio_params[:original_format] = Mime::Type.lookup(audio_params[:media_type].downcase).to_sym.to_s if audio_params[:original_format].blank?

            # enqueue
            BawWorkers::AudioCheck::Action.action_enqueue(audio_params)
          end


        end


        desc 'Enqueue audio recording file checks from audio files to be processed using Resque worker'
        task :from_files, [:settings_file] => ['worker:init_redis'] do |t, args|

          # find all valid files in folder

          # enqueue each file
          BawWorkers::AudioCheck::Action.action_enqueue(audio_params)
        end

      end

      namespace :standalone do

        desc 'Enqueue audio recording file checks from a csv file to be processed using Resque worker'
        task :from_csv, [:settings_file] => ['worker:init_settings'] do |t, args|

          # read csv

          # process all files from csv
        end

        desc 'Enqueue audio recording file checks from audio files to be processed using Resque worker'
        task :from_files, [:settings_file] => ['worker:init_settings'] do |t, args|

          # find all valid files in folder

          # process all files
        end
      end

    end
  end
end