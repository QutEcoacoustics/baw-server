require 'csv'

# run using e.g.
# bin/rake baw:export:audio_recordings['1028 1029','/tmp/test_export_ar.csv'] RAILS_ENV=development
namespace :baw do
  namespace :audio_recordings do

    desc 'Fix format of notes field for audio recordings.'
    task :repair_notes => :environment do |t, args|
      puts ''
      puts "Checking #{AudioRecording.where('notes IS NOT NULL').count} audio recording notes..."
      puts ''
      AudioRecording.where('notes IS NOT NULL').order(id: :asc).find_each do |ar| # .where('id > 240000')
        ar_notes = AudioRecording.connection.select_all(AudioRecording.where(id: ar.id).select(:notes).to_sql).first['notes']
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

        # check that all lines are INI-style
        if processed_note_lines < total_note_lines
          fail ArgumentError, "Didn't process all lines for audio recording id #{ar.id}."
        end

        # processing
        fix_double_quotes(result_hash, 'dep_entity_notes')
        fix_double_quotes(result_hash, 'dep_notes')
        fix_double_quotes(result_hash, 'site_notes')

        fix_overlap(result_hash)

        # check that all lines are recognised
        single_value_keys = [
            'dep_entity_id', 'dep_entity_name', 'dep_entity_createdby', 'dep_entity_createdby_name',
            'dep_entity_type', 'dep_entity_depid', 'dep_entity_createddate', 'dep_id', 'dep_hardwareid',
            'dep_name', 'dep_datestarted', 'dep_desc', 'dep_istest', 'dep_createdby', 'dep_createdby_name',
            'dep_createdtime', 'dep_isactive', 'dep_timeout', 'dep_issensitive', 'hardware_id',
            'hardware_uniqueid', 'hardware_friendly', 'hardware_manual', 'hardware_createdby',
            'hardware_createdby_name', 'hardware_createdtime', 'site_id', 'site_name', 'site_createdby',
            'site_createdby_name', 'site_type', 'site_geo', 'site_geo_lat', 'site_geo_long', 'site_geobinary',
            'site_geobinary_lat', 'site_geobinary_long', 'site_createddate', 'dep_approx_long', 'dep_approx_lat',
            'dep_locationapprox', 'dep_locationapprox_lat', 'dep_locationapprox_long', 'dep_locationapproxbinary',
            'dep_locationapproxbinary_lat', 'dep_locationapproxbinary_long', 'dep_long', 'dep_lat', 'dep_location',
            'dep_location_lat', 'dep_location_long', 'dep_locationbinary', 'dep_locationbinary_lat',
            'dep_locationbinary_long', 'hardware_lastcontacted', 'dep_entity_geobinary', 'dep_entity_geobinary_lat',
            'dep_entity_geobinary_long', 'dep_datended', 'UploadStartUTC',

            'dep_entity_notes', 'dep_notes', 'site_notes',

            'duration_adjustment_for_overlap'
        ]
        require_processing_keys = []
        recognised_keys = single_value_keys + require_processing_keys
        comparison = result_hash.keys - recognised_keys
        unless comparison.empty?
          fail ArgumentError, "Unrecognised keys for id #{ar.id}: #{comparison.join(', ')}."
        end

        if result_hash.keys.to_set.intersect?(require_processing_keys.to_set)

          puts ''
          puts "Notes for #{ar.id}:"

          result_hash.slice(*require_processing_keys).each do |key, value|
            puts ''
            print key, ':', value
          end
          puts ''
        else
          #print '.'
        end

      end

      puts ''
      puts '...done.'

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

def fix_double_quotes(hash, key)
  if hash.include?(key) &&
      !hash[key].blank? &&
      hash[key].start_with?('\\"') &&
      hash[key].end_with?('\\"')
    hash[key] = hash[key][2..-3]
  end
end

def fix_overlap(hash)

  key = 'duration_adjustment_for_overlap'
  infos = []

  # collect all overlap infos
  keys = hash.keys.select { |k| k.start_with?(key) }
  values = hash.slice(*keys).values

  # parse each value and add object to overlap array
  values.each do |overlap_string|

    # Change made 2014-12-01T00:10:37Z: overlap of 10.004800081253052 seconds with audio_recording with uuid 8284b364-b1ee-491a-a2bf-8b489e1d94b8.
    regex = /^Change made (.+): overlap of (.+) seconds with audio_recording with uuid (.+)\.$/
    overlap_string.scan(regex) do |changed_at, overlap_amount, other_uuid|
      infos.push({
                     changed_at: changed_at,
                     overlap_amount: overlap_amount.to_f,
                     old_duration: nil,
                     new_duration: nil,
                     other_uuid: other_uuid
                 })
    end

    # Change made 2015-07-10T06:34:38Z: overlap of 1.003 seconds (duration: old: 23008.003, new: 23007.0) with audio_recording with uuid 12d8eb2e-c793-499e-baf1-14ff163f90c0.
    regex = /^Change made (.+): overlap of (.+) seconds \(duration: old: (.+), new: (.+)\) with audio_recording with uuid (.+)\.$/
    overlap_string.scan(regex) do |changed_at, overlap_amount, old_duration, new_duration, other_uuid|
      infos.push({
                     changed_at: changed_at,
                     overlap_amount: overlap_amount.to_f,
                     old_duration: old_duration.to_f,
                     new_duration: new_duration.to_f,
                     other_uuid: other_uuid
                 })
    end

    # Change made 2015-06-11T06:03:28Z: overlap of 0.003 seconds with audio_recording with uuid .
    regex = /^Change made (.+): overlap of (.+) seconds with audio_recording with uuid \.$/
    overlap_string.scan(regex) do |changed_at, overlap_amount |
      infos.push({
                     changed_at: changed_at,
                     overlap_amount: overlap_amount.to_f,
                     old_duration: nil,
                     new_duration: nil,
                     other_uuid: nil
                 })
    end

  end

  if keys.size > 0 && infos.size != keys.size
    puts ''
    puts keys
    puts values
    puts infos
    puts ''
  end

  # remove overlap_strings from hash
  keys.each { |k| hash.delete(k) }

  # save infos back to hash
  hash['duration_adjustment_for_overlap'] = infos

end