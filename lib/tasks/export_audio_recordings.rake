require 'csv'

# run using e.g.
# bin/rake baw:export:audio_recordings['1028 1029','/tmp/test_export_ar.csv'] RAILS_ENV=development
namespace :baw do
  namespace :export do

    desc 'Export audio recordings to a csv file to be used by the baw-workers analysis action.'
    task :audio_recordings, [:site_ids, :output_file] => :environment do |t, args|
      site_ids = args.site_ids.split(' ').map { |i| i.to_i }.compact

      audio_recordings = AudioRecording.where(site_id: site_ids).pluck(:id, :recorded_date, :uuid, :original_file_name, :media_type)

      puts "Writing #{audio_recordings.count} audio recordings to csv file..."

      CSV.open(args.output_file, 'w',
               write_headers: true,
               headers: %w(id datetime_with_offset uuid original_file_name media_type original_format)
      ) do |writer|
        audio_recordings.each do |ar|
          id = 0
          datetime_with_offset = 1
          uuid = 2
          original_file_name = 3
          media_type = 4
          original_format = 5

          original_format = nil
          if !ar[original_file_name].blank?
            original_format = File.extname(ar[original_file_name])
          elsif !ar[media_type].blank?
            original_format = Mime::Type.file_extension_of(ar[media_type])
          end

          original_format = NameyWamey.trim(original_format, '.', '')

          data_item = [
              ar[id],
              ar[datetime_with_offset],
              ar[uuid],
              ar[original_file_name],
              ar[media_type],
              original_format
          ]

          print '.'

          writer << data_item
        end
      end

      puts ''
      puts '... done.'

    end

  end
end