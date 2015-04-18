require 'csv'

# Postgresql query to export csv file
# COPY (SELECT id, uuid, recorded_date || 'Z', duration_seconds,
# sample_rate_hertz, channels,bit_rate_bps, media_type, data_length_bytes,
# file_hash, original_file_name FROM "audio_recordings"
#      ) TO '/tmp/audio_recordings_to_check.csv' DELIMITER ',' CSV HEADER;

module BawWorkers
  module AudioCheck
    class CsvHelper
      class << self

        def logged_csv_line(file_path, exists, moved_path = nil,
                            compare_hash = nil, api_result_hash = nil,
                            api_response = nil, review_level = :none_all_good)
          csv_headers = [
              :file_path, :exists,

              :moved_path,
              :errors,

              :check_new_file_name, :check_file_errors,

              :check_file_hash, :check_extension, :check_media_type,
              :check_sample_rate_hertz, :check_channels, :check_bit_rate_bps,
              :check_data_length_bytes, :check_duration_seconds,

              :expected_file_hash, :expected_extension, :expected_media_type,
              :expected_sample_rate_hertz, :expected_channels, :expected_bit_rate_bps,
              :expected_data_length_bytes, :expected_duration_seconds,

              :actual_file_hash, :actual_extension, :actual_media_type,
              :actual_sample_rate_hertz, :actual_channels, :actual_bit_rate_bps,
              :actual_data_length_bytes, :actual_duration_seconds,

              :api_file_hash, :api_media_type,
              :api_sample_rate_hertz, :api_channels, :api_bit_rate_bps,
              :api_data_length_bytes, :api_duration_seconds,

              :api_response,

              :review_level
          ]

          csv_values = []

          # file path and exists must always be available
          csv_values[0] = file_path
          csv_values[1] = exists

          # add moved path - this might be nil if the file wasn't moved
          csv_values[2] = moved_path unless moved_path.nil?

          # add all the info from comparison hash if it is available
          unless compare_hash.blank?
            csv_values[3] = compare_hash[:actual][:errors]

            csv_values[4] = compare_hash[:checks][:new_file_name]
            csv_values[5] = compare_hash[:checks][:file_errors]

            csv_values[6] = compare_hash[:checks][:file_hash]
            csv_values[7] = compare_hash[:checks][:extension]
            csv_values[8] = compare_hash[:checks][:media_type]
            csv_values[9] = compare_hash[:checks][:sample_rate_hertz]
            csv_values[10] = compare_hash[:checks][:channels]
            csv_values[11] = compare_hash[:checks][:bit_rate_bps]
            csv_values[12] = compare_hash[:checks][:data_length_bytes]
            csv_values[13] = compare_hash[:checks][:duration_seconds]

            csv_values[14] = compare_hash[:expected][:file_hash]
            csv_values[15] = compare_hash[:expected][:extension]
            csv_values[16] = compare_hash[:expected][:media_type]
            csv_values[17] = compare_hash[:expected][:sample_rate_hertz]
            csv_values[18] = compare_hash[:expected][:channels]
            csv_values[19] = compare_hash[:expected][:bit_rate_bps]
            csv_values[20] = compare_hash[:expected][:data_length_bytes]
            csv_values[21] = compare_hash[:expected][:duration_seconds]

            csv_values[22] = compare_hash[:actual][:file_hash]
            csv_values[23] = compare_hash[:actual][:extension]
            csv_values[24] = compare_hash[:actual][:media_type]
            csv_values[25] = compare_hash[:actual][:sample_rate_hertz]
            csv_values[26] = compare_hash[:actual][:channels]
            csv_values[27] = compare_hash[:actual][:bit_rate_bps]
            csv_values[28] = compare_hash[:actual][:data_length_bytes]
            csv_values[29] = compare_hash[:actual][:duration_seconds]
          end

          # add values from api results
          api_result_hash_blank = api_result_hash.blank?

          csv_values[30] = api_result_hash_blank ? :notsent : api_result_hash.include?(:file_hash) ? :updated : :noaction
          csv_values[31] = api_result_hash_blank ? :notsent : api_result_hash.include?(:media_type) ? :updated : :noaction
          csv_values[32] = api_result_hash_blank ? :notsent : api_result_hash.include?(:sample_rate_hertz) ? :updated : :noaction
          csv_values[33] = api_result_hash_blank ? :notsent : api_result_hash.include?(:channels) ? :updated : :noaction
          csv_values[34] = api_result_hash_blank ? :notsent : api_result_hash.include?(:bit_rate_bps) ? :updated : :noaction
          csv_values[35] = api_result_hash_blank ? :notsent : api_result_hash.include?(:data_length_bytes) ? :updated : :noaction
          csv_values[36] = api_result_hash_blank ? :notsent : api_result_hash.include?(:duration_seconds) ? :updated : :noaction

          # record response from api request
          api_response_value = api_response.nil? ? :invalid : api_response
          csv_values[37] = api_response_value

          # review level
          csv_values[38] = review_level

          {
              headers: csv_headers,
              values: csv_values
          }
        end

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

          # load csv file
          CSV.foreach(csv_file, {headers: true, return_headers: false}) do |row|

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

            # provide the audio parameters to yield
            yield audio_params if block_given?
          end
        end

        # extract the CSV log lines from a log file.
        def extract_csv_logs(read_path, write_path)
          # for lines that start with a datestamp (format: 2015-04-12T23:06:48.295+0000) and log info
          # keep only if the row then contains '[CSV], '.

          line_start_regexp = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}\+\d{4} \[[^\]]+\] \[CSV\], /

          File.open(write_path, 'a') do |dest|

            File.open(read_path).each_line do |line|
              next unless line.match(line_start_regexp)
              dest.puts line
            end

          end

        end


      end
    end
  end
end