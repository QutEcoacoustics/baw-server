require 'csv'

namespace :baw do
namespace :action do
  desc 'Enqueue audio recording file checks using Resque'
  task :audio_check, [:settings_file, :csv_file] => ['worker:init'] do |t, args|

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
        hash.merge( k.to_sym => row[k.to_s] )
      end

      # special case for original_format
      # get original_format from original_file_name
      original_file_name = audio_params.delete(:original_file_name)
      original_extension = original_file_name.blank? ? '' : File.extname(original_file_name).trim('.','').downcase
      audio_params[:original_format] = original_extension

      # get extension from media_type
      audio_params[:original_format] = Mime::Type.lookup(audio_params[:media_type].downcase).to_sym.to_s if audio_params[:original_format].blank?

      # enqueue
      BawWorkers::AudioCheck::Action.enqueue(audio_params)
    end


  end

  end
end