require 'csv'

# run using e.g.
# bin/rake baw:export:audio_recordings['1028 1029','/tmp/test_export_ar.csv'] RAILS_ENV=development
namespace :baw do
  namespace :audio_recordings do

    desc 'Fix format of notes field for audio recordings.'
    task :repair_notes => :environment do |t, args|
      AudioRecording.where('notes IS NOT NULL').find_each do |ar|
        ar_notes = ar.notes
        note_lines = ar_notes.split(/\r\n|\n\r|\r|\n/).reject { |item| item.blank? }

        total_note_lines = note_lines.size
        processed_note_lines = 0

        result_hash = {}

        # for each line that matches ini-style, add to hash
        note_lines.each do |note_line|
          note_line.scan(/\A"(.*)"="(.*)"\z/) do |key, value|
            ensure_new_key(result_hash, key, value)
            processed_note_lines += 1
          end
        end

        if processed_note_lines < total_note_lines
          fail ArgumentError, "Didn't process all lines for audio recording id #{ar.id}."
        end

        p "Notes for #{ar.id}: #{result_hash}"
      end
    end
  end
end

def ensure_new_key(hash, key, value)
  append_num = 0
  loop do
    current_key = append_num > 0 ? "#{key}_#{append_num}" : key
    if hash.include?(current_key)
      append_num += 1
    else
      hash[current_key] = value
      break
    end
  end
end