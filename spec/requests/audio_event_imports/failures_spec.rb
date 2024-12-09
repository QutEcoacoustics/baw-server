# frozen_string_literal: true

require_relative 'audio_event_import_context'

describe 'failures' do
  include_context 'with audio event import context'

  before do
    create_import
  end

  [true, false].each do |commit|
    describe "(with commit: #{commit})" do
      it 'explains a lack of columns if they are missing' do
        f = temp_file(basename: 'generic_example.csv')
        f.write <<~CSV
          audio_recording_id          ,start_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
          #{second_audio_recording.id},789               ,100                ,500                 ,Birb
        CSV

        submit(f, commit:)

        expect_error(
          :unprocessable_content,
          'Record could not be saved',
          {
            file: ['Validation failed']
          },
          with_data_matching: a_hash_including(
            imported_events: [
              a_hash_including(
                errors: [
                  {
                    end_time_seconds: ['is missing']
                  }
                ]
              )
            ]
          )
        )

        expect(AudioEvent.count).to eq 0
      end

      it 'surfaces audio event errors' do
        f = temp_file(basename: 'generic_example.csv')
        f.write <<~CSV
          audio_recording_id          ,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
          #{second_audio_recording.id},789               ,456             ,100                ,500                 ,Birb
        CSV

        submit(f, commit:)

        expect_error(
          :unprocessable_content,
          'Record could not be saved',
          {
            file: ['Validation failed']
          },
          with_data_matching: a_hash_including(
            imported_events: [
              a_hash_including(
                start_time_seconds: 789,
                errors: [
                  {
                    start_time_seconds: ['must be less than or equal to `end_time_seconds`']
                  }
                ]
              )
            ]
          )
        )

        expect(AudioEvent.count).to eq 0
      end

      it 'reports bad audio recording ids' do
        modified_content = generic_example.read.gsub("#{second_audio_recording.id},", '999999999,')
        generic_example.write(modified_content)

        submit(generic_example, commit:)

        expect_error(
          :unprocessable_content,
          'Record could not be saved',
          {
            file: ['Validation failed']
          },
          with_data_matching: a_hash_including(
           imported_events: [
             a_hash_including(
               audio_recording_id: 999_999_999,
               errors: [
                 {
                   audio_recording_id: ['does not exist']
                 }
               ]
             )
           ]
         )
        )

        expect(AudioEvent.count).to eq 0
      end

      it 'rejects files that are not on the acceptable list' do
        submit(Fixtures.audio_file_mono, commit:)

        expect_error(:unprocessable_content, 'Record could not be saved', {
          file: ['is not an acceptable content type']
        })

        expect(AudioEvent.count).to eq 0
      end

      it 'rejects files that are not on the acceptable list (extension spoofing)' do
        example = temp_file(basename: 'bad.csv')
        example.write(Fixtures.audio_file_mono.read)

        submit(example, commit:)

        expect_error(:unprocessable_content, 'Record could not be saved', {
          file: ['is not an acceptable content type']
        })

        expect(AudioEvent.count).to eq 0
      end

      it 'rejects files that have no audio events' do
        example = temp_file(basename: 'no_events.csv')
        example.write <<~CSV
          audio_recording_id,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
        CSV

        submit(example, commit:)
        expect_error(:unprocessable_content, 'Record could not be saved', {
          file: ['must have at least one audio event but 0 were found']
        }, with_data_matching: a_hash_including(imported_events: []))

        expect(AudioEvent.count).to eq 0
      end

      it 'rejects duplicate uploads' do
        submit(raven_example, commit: true)
        expect_success
        id = api_data[:id]

        submit(raven_example, commit:)
        expect_error(:unprocessable_content, 'Record could not be saved', {
          file: ["is not unique. Duplicate record found with id: #{id}"]
        })

        expect(AudioEvent.count).to eq 2
      end

      it 'rejects files that are too large' do
        # just create a file that is too large
        source = temp_file(extension: '.csv')
        (1..10).each do |_i|
          source.write(Fixtures.hoot_detective.read, mode: 'a')
        end
        expect(source.size).to be > Settings.audio_event_imports.max_file_size_bytes

        submit(source, commit:)
        expect_error(:unprocessable_content, 'Record could not be saved', {
          file: ['is too large, must be less than 10 MB']
        })

        expect(AudioEvent.count).to eq 0
      end
    end
  end
end
