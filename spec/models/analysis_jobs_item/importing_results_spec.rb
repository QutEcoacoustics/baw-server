# frozen_string_literal: true

describe AnalysisJobsItem do
  describe 'importing results' do
    create_entire_hierarchy

    let(:another_recording) { create(:audio_recording, site:) }

    before do
      analysis_jobs_item.result_success!
      Bullet.enable = false
      analysis_jobs_item.audio_event_import_files.destroy_all
    ensure
      Bullet.enable = true
    end

    describe 'successful import' do
      before do
        create_analysis_result_file(analysis_jobs_item, Pathname('ignoreme.txt'), content:
          <<~CSV
            filename,start_offset_seconds,end_offset_seconds,label,score
            tests/files/audio/100sec.wav,0.0,5.0,GREMLIN,-11.764339
          CSV
        )
        create_analysis_result_file(analysis_jobs_item, Pathname('sub_folder/generic_example.csv'), content:
          <<~CSV
            audio_recording_id          ,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
            #{audio_recording.id},123               ,456             ,100                ,500                 ,Birb
          CSV
        )

        create_analysis_result_file(analysis_jobs_item, Pathname('more_results.csv'), content:
          <<~CSV
            filename,start_offset_seconds,end_offset_seconds,label,score
            tests/files/audio/100sec.wav,0.0,5.0,wascawwy wabbit,-11.764339
            tests/files/audio/100sec.wav,5.0,10.0,wascally wabbit,-14.89451
          CSV
        )
      end

      it 'can import results' do
        result = analysis_jobs_item.import_results!
        expect(result).to be_success

        item = analysis_jobs_item.reload

        file_imports = item.audio_event_import_files
        import = item.analysis_job.audio_event_imports.first

        # the txt file should be ignored based on the script glob
        expect(file_imports.size).to be(2)

        first = file_imports.first
        second = file_imports.second

        expect(first).to match(an_object_having_attributes(
          path: 'more_results.csv',
          audio_event_import_id: import.id,
          analysis_jobs_item_id: item.id
        ))

        expect(second).to match(an_object_having_attributes(
          path: 'sub_folder/generic_example.csv',
          audio_event_import_id: import.id,
          analysis_jobs_item_id: item.id
        ))

        expect(import.name).to eq "Import for #{item.analysis_job.name}"

        events = AudioEvent.by_import(import.id).order(:start_time_seconds, :end_time_seconds).includes([:tags]).all

        expect(events.size).to be(3)
        expect(events).to match([

          an_object_having_attributes(
            audio_recording_id: audio_recording.id,
            channel: nil,
            start_time_seconds: eq(0.0),
            end_time_seconds: eq(5.0),
            audio_event_import_file_id: first.id,
            import_file_index: 0,
            provenance_id: analysis_jobs_item.script.provenance.id,
            score: -11.764339
          ),
          an_object_having_attributes(
            audio_recording_id: audio_recording.id,
            channel: nil,
            start_time_seconds: eq(5.0),
            end_time_seconds: eq(10.0),
            audio_event_import_file_id: first.id,
            import_file_index: 1,
            provenance_id: analysis_jobs_item.script.provenance.id,
            score: -14.89451
          ),
          an_object_having_attributes(
            audio_recording_id: audio_recording.id,
            channel: nil,
            start_time_seconds: eq(123),
            end_time_seconds: eq(456),
            low_frequency_hertz: 100,
            high_frequency_hertz: 500,
            audio_event_import_file_id: second.id,
            import_file_index: 0,
            provenance_id: analysis_jobs_item.script.provenance.id,
            score: nil
          )
        ])

        expect(events.map(&:tags).flatten.map(&:text)).to match([
          'wascawwy wabbit',
          'wascally wabbit',
          'Birb'
        ])
      end
    end

    it 'cannot override audio recording id' do
      create_analysis_result_file(analysis_jobs_item, Pathname('malicious.csv'), content:
      <<~CSV
        audio_recording_id          ,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
        #{another_recording.id},123               ,456             ,100                ,500                 ,Birb
      CSV
      )

      result = analysis_jobs_item.import_results!
      expect(result).to be_success

      item = analysis_jobs_item.reload

      file_imports = item.audio_event_import_files
      import = item.analysis_job.audio_event_imports.first

      expect(file_imports.size).to be(1)

      events = AudioEvent.by_import(import.id).order(:start_time_seconds, :end_time_seconds).all

      expect(events).to match([
        an_object_having_attributes(
          audio_recording_id: audio_recording.id
        )
      ])
    end

    it 'cannot import the same file path twice' do
      create_analysis_result_file(analysis_jobs_item, Pathname('sub_folder/generic_example.csv'), content:
      <<~CSV
        audio_recording_id          ,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
        #{audio_recording.id},123               ,456             ,100                ,500                 ,Birb
      CSV
      )

      result = analysis_jobs_item.import_results!
      expect(result).to be_success

      expect {
        analysis_jobs_item.import_results!
      }.to raise_error(NotImplementedError, 'Results have already been imported, don\'t know how to handle this')
    end

    it 'only commits if all files are successful' do
      before_audio_events = AudioEvent.count
      before_audio_event_import_files = AudioEventImportFile.count

      create_analysis_result_file(analysis_jobs_item, Pathname('sub_folder/generic_example.csv'), content:
      <<~CSV
        audio_recording_id          ,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
        #{audio_recording.id},123               ,456             ,100                ,500                 ,Birb
      CSV
      )

      create_analysis_result_file(analysis_jobs_item, Pathname('sub_folder/generic_example2.csv'), content:
      <<~CSV
        audio_recording_id          ,start_time_seconds_MISSPELT,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
        #{audio_recording.id},123               ,456             ,100                ,500                 ,Birb
      CSV
      )

      result = analysis_jobs_item.import_results!
      expect(result).to be_failure
      expect(result.failure).to eq([
        "Failure importing `sub_folder/generic_example2.csv`, validation failed: 'start_time_seconds is missing'"
      ])

      expect(AudioEvent.count).to eq(before_audio_events)
      expect(AudioEventImportFile.count).to eq(before_audio_event_import_files)
    end
  end
end
