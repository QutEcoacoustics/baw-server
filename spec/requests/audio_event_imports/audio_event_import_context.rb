# frozen_string_literal: true

RSpec.shared_context(
  'with audio event import context'
) do
  extend WebServerHelper::ExampleGroup

  create_entire_hierarchy

  before do
    # remove from the standard hierarchy
    audio_event_import.destroy
    # hard delete
    AudioEvent.delete_all
  end

  let(:machine_generated_tag) {
    create(:tag, text: 'machine generated', type_of_tag: 'general')
  }

  let(:raven_filename) {
    "#{audio_recording.friendly_name}.Table.1.selections.txt"
  }

  let(:raven_example) {
    f = temp_file(basename: raven_filename)
    f.write <<~FILE
      Selection	View	Channel	Begin Time (s)	End Time (s)	Low Freq (Hz)	High Freq (Hz)	Delta Time (s)	Delta Freq (Hz)	Avg Power Density (dB FS/Hz)	Annotation
      1	Waveform 1	1	6.709509878	15.096397225	1739.012	3798.813	8.3869	2059.801		Birb
      1	Spectrogram 1	1	6.709509878	15.096397225	1739.012	3798.813	8.3869	2059.801	-75.87	Birb
      2	Waveform 1	1	29.383026016	40.257059266	1587.060	4136.485	10.8740	2549.426		donkey
      2	Spectrogram 1	1	29.383026016	40.257059266	1587.060	4136.485	10.8740	2549.426	-75.64	donkey
    FILE
    f
  }

  let(:second_audio_recording) { create(:audio_recording, site_id: site.id) }

  let(:generic_example) {
    f = temp_file(basename: 'generic_example.csv')
    f.write <<~CSV
      audio_recording_id          ,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
      #{second_audio_recording.id},123               ,456             ,100                ,500                 ,Birb
    CSV
    f
  }

  def create_import(user: writer_token)
    body = {
      audio_event_import: {
        name: 'import a',
        description: '**hello**'
      }
    }

    post '/audio_event_imports', params: body, **api_headers(user)

    expect_success

    expect(api_data).to match(a_hash_including(
      id: be_an_instance_of(Integer),
      name: 'import a',
      description: '**hello**'
    ))

    @audio_event_import = AudioEventImport.find(api_data[:id])
  end

  def submit(file, commit: true, additional_tags: [], user: writer_token)
    body = {
      audio_event_import_file: {
        file: with_file(file),
        additional_tag_ids: additional_tags.map(&:id)
      },
      commit:
    }

    post "/audio_event_imports/#{@audio_event_import.id}/files", params: body, **form_multipart_headers(user)
  end

  def assert_success(committed:, name:, imported_events: [], additional_tags: [])
    expect_success
    expect(api_data).to match(a_hash_including(
      id: committed ? be_an_instance_of(Integer) : be_nil,
      additional_tag_ids: additional_tags.map(&:id),
      audio_event_import_id: @audio_event_import.id,
      analysis_jobs_item_id: be_nil,
      created_at: committed ? be_a(String) : be_nil,
      path: committed ? be_a(String) : be_nil,
      name:,
      committed:,
      imported_events:
    ))

    # our safe guard for the insert_all! method
    imported_events = @audio_event_import
      .audio_event_import_files
      .flat_map(&:audio_events)
    expect(imported_events).to all(be_valid)

    id = api_data[:id]

    assert_file_downloadable(api_data[:path]) if committed

    id
  end

  def assert_file_downloadable(path)
    get path, **api_headers(writer_token)
    expect_success
  end
end
