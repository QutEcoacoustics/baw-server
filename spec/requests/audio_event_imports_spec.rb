# frozen_string_literal: true

describe '/audio_event_imports' do
  extend WebServerHelper::ExampleGroup

  create_entire_hierarchy
  expose_app_as_web_server

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
    f = temp_file(extension: 'csv')
    f.write <<~CSV
      audio_recording_id          ,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
      #{second_audio_recording.id},123               ,456             ,100                ,500                 ,Birb
    CSV
    f
  }

  def submit(file, commit: true, additional_tags: [], user: writer_token)
    body = {
      audio_event_import: {
        name: 'import a',
        description: '**hello**'
      },
      import: {
        file: with_file(file),
        additional_tag_ids: additional_tags.map(&:id),
        commit:
      }
    }

    post '/audio_event_imports', params: body, **form_multipart_headers(user)
  end

  def assert_success(imported_events: [], files: [])
    expect_success
    expect(api_data).to match(a_hash_including(
      id: be_an_instance_of(Integer),
      name: 'import a',
      description: '**hello**',
      files:,
      imported_events:
    ))

    api_data[:id]
  end

  it 'can accept a file and payload at the same time' do
    submit(raven_example)
    id = assert_success(imported_events: [
      a_hash_including(
        id: be_an_instance_of(Integer),
        errors: [],
        start_time_seconds: be_within(0.001).of(6.709509878),
        tags: [
          a_hash_including(text: 'Birb')
        ]
      ),
      a_hash_including(
        id: be_an_instance_of(Integer),
        errors: [],
        start_time_seconds: be_within(0.001).of(29.383026016),
        tags: [
          a_hash_including(text: 'donkey')
        ]
      )
    ], files: [
      { name: raven_filename, additional_tags: [], imported_at: be_an_instance_of(String) }
    ])

    expect(AudioEvent.by_import(id).count).to eq 2
  end

  it 'will not commit if commit is false' do
    submit(raven_example, commit: false)
    id = assert_success(imported_events: [
      a_hash_including(
        id: nil,
        errors: [],
        start_time_seconds: be_within(0.001).of(6.709509878),
        tags: [
          a_hash_including(text: 'Birb')
        ]
      ),
      a_hash_including(
        id: nil,
        errors: [],
        start_time_seconds: be_within(0.001).of(29.383026016),
        tags: [
          a_hash_including(text: 'donkey')
        ]
      )
    ])

    expect(AudioEvent.by_import(id).count).to eq 0
  end

  it 'can accept additional_tags' do
    submit(raven_example, additional_tags: [machine_generated_tag])
    id = assert_success(imported_events: [
      a_hash_including(
        id: be_an_instance_of(Integer),
        errors: [],
        start_time_seconds: be_within(0.001).of(6.709509878),
        tags: [
          a_hash_including(text: 'Birb'),
          a_hash_including(id: machine_generated_tag.id, text: 'machine generated')
        ]
      ),
      a_hash_including(
        id: be_an_instance_of(Integer),
        errors: [],
        start_time_seconds: be_within(0.001).of(29.383026016),
        tags: [
          a_hash_including(text: 'donkey'),
          a_hash_including(id: machine_generated_tag.id, text: 'machine generated')
        ]
      )
    ], files: [
      { name: raven_filename, additional_tags: [machine_generated_tag.id], imported_at: be_an_instance_of(String) }
    ])

    expect(AudioEvent.by_import(id).count).to eq 2

    events = AudioEvent.by_import(id)
    expect(events.count).to eq 2
    expect(events.all.to_a).to all(have_attributes(tags: include(machine_generated_tag)))
  end

  stepwise 'can accept files after creation' do
    step 'create import with no events' do
      first_body = {
        audio_event_import: {
          name: 'import a',
          description: '**hello**'
        }
      }

      post '/audio_event_imports', params: first_body, **api_with_body_headers(writer_token)
      expect_success
    end

    step 'check created import' do
      expect(api_data).to match(a_hash_including(
        id: be_an_instance_of(Integer),
        name: 'import a',
        description: '**hello**',
        files: [],
        imported_events: []
      ))

      @id = api_data[:id]
    end

    step 'send a file of events to import' do
      second_body = {
        import: {
          file: with_file(raven_example),
          additional_tag_ids: [],
          commit: true
        }
      }

      put "/audio_event_imports/#{@id}", params: second_body, **form_multipart_headers(writer_token)

      expect_success
    end

    step 'check for success' do
      expect(api_data).to match(a_hash_including(
        id: be_an_instance_of(Integer),
        name: 'import a',
        description: '**hello**',
        files: [
          { name: raven_filename, additional_tags: [], imported_at: be_an_instance_of(String) }
        ],
        imported_events: [
          a_hash_including(
            id: be_an_instance_of(Integer),
            errors: [],
            start_time_seconds: be_within(0.001).of(6.709509878),
            tags: [
              a_hash_including(text: 'Birb')
            ]
          ),
          a_hash_including(
            id: be_an_instance_of(Integer),
            errors: [],
            start_time_seconds: be_within(0.001).of(29.383026016),
            tags: [
              a_hash_including(text: 'donkey')
            ]
          )
        ]
      ))
    end

    step 'send another file' do
      third_body = {
        import: {
          file: with_file(generic_example),
          additional_tag_ids: [machine_generated_tag.id],
          commit: true
        }
      }

      put "/audio_event_imports/#{@id}", params: third_body, **form_multipart_headers(writer_token)

      expect_success
    end

    step 'check for updated events' do
      expect(api_data).to match(a_hash_including(
        id: be_an_instance_of(Integer),
        name: 'import a',
        description: '**hello**',
        files: [
          { name: raven_filename, additional_tags: [], imported_at: be_an_instance_of(String) },
          {
            name: generic_example.basename.to_s,
            additional_tags: [machine_generated_tag.id],
            imported_at: be_an_instance_of(String)
          }
        ],
        imported_events: [
          a_hash_including(
            id: be_an_instance_of(Integer),
            errors: [],
            start_time_seconds: be_within(0.001).of(123),
            tags: [
              a_hash_including(text: 'Birb'),
              a_hash_including(id: machine_generated_tag.id, text: machine_generated_tag.text)
            ]
          )
        ]
      ))
    end

    step '3 Audio events should have been registered' do
      events = AudioEvent.by_import(@id)
      expect(events.count).to eq 3
    end
  end

  describe 'permissions' do
    let(:another_project) {
      create(:project)
    }

    let(:another_region) {
      create(:region, project: another_project)
    }

    let(:another_site) {
      create(:site, region: another_region)
    }

    let(:another_audio_recording) {
      create(:audio_recording, site: another_site)
    }

    before do
      AudioEvent.all.delete_all
    end

    it 'will not allow audio event creation for projects a user does not have write access too' do
      f = temp_file(extension: 'csv')
      f.write <<~CSV
        audio_recording_id          ,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
        #{audio_recording.id}       ,123               ,456             ,100                ,500                 ,Birb
        #{another_audio_recording.id},123              ,456             ,100                ,500                 ,Birb
      CSV

      submit(f)

      expect_error(:forbidden, nil)

      expect(AudioEvent.count).to eq 0
    end

    it 'will not allow readers to upload events' do
      submit(generic_example, user: reader_token)

      expect_error(:forbidden, nil)

      expect(AudioEvent.count).to eq 0
    end
  end

  describe 'failures' do
    it 'will explain why it failed for audio recording id mismatches' do
      pending
    end

    it 'will explain a lack of columns if they are missing' do
      pending
    end

    it 'will surface audio event errors' do
      pending
    end

    it 'will report bad audio recording ids' do
      pending
    end
  end

  describe 'deletion' do
    it 'will recursively soft-delete all associated audio events' do
      pending
    end

    it 'with a hard delete it will delete all associated audio events' do
      pending
    end
  end
end
