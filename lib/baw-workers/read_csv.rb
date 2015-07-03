require 'csv'

module BawWorkers
  class ReadCsv
    class << self

      def read_audio_recording_csv(csv_file)
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

        audio_params_array = []

        # load csv file
        CSV.foreach(csv_file, {headers: true, return_headers: false}) do |row|

          # get values from row, put into hash that matches what check action expects
          audio_params = index_to_key_map.inject({}) do |hash, (k, v)|
            hash.merge(k.to_sym => row[k.to_s])
          end

          # try a few ways to get original_format
          original_format = audio_params[:original_format]

          if original_format.blank?
            original_file_name = audio_params[:original_file_name]
            original_extension = original_file_name.blank? ? '' : File.extname(original_file_name).trim('.', '').downcase
            original_format = original_extension
          end

          original_format = Mime::Type.lookup(audio_params[:media_type].downcase).to_sym.to_s if original_format.blank?

          audio_params[:original_format] = original_format

          audio_params_array.push(audio_params)

          # provide the audio parameters to yield
          yield audio_params if block_given?
        end

        audio_params_array
      end

    end
  end
end
