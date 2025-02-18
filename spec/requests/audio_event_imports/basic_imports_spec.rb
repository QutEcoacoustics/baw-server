# frozen_string_literal: true

require_relative 'audio_event_import_context'

describe '/audio_event_imports' do
  include_context 'with audio event import context'

  it 'can update the name and description' do
    create_import

    params = {
      audio_event_import: {
        name: 'new name',
        description: 'new description'
      }
    }

    put audio_event_import_path(@audio_event_import), params:, **api_headers(writer_token)

    expect_success
    expect(api_data).to match(a_hash_including(
      id: @audio_event_import.id,
      name: 'new name',
      description: 'new description'
    ))
  end

  it 'can do a basic import' do
    create_import
    submit(raven_example, commit: true)
    assert_success(committed: true, name: raven_filename, imported_events: [
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
    ])

    events = AudioEvent.by_import(@audio_event_import.id)
    expect(events.count).to eq 2
    expect(events.all.flat_map(&:tags).map(&:text)).not_to include(machine_generated_tag.text)
  end

  it 'does not commit if commit is false' do
    create_import
    submit(raven_example, commit: false)
    assert_success(committed: false, name: raven_filename, imported_events: [
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

    expect(AudioEvent.by_import(@audio_event_import.id).count).to eq 0
  end

  it 'can accept additional_tags' do
    create_import
    submit(raven_example, commit: true, additional_tags: [machine_generated_tag])
    assert_success(
      committed: true,
      name: raven_filename,
      imported_events: [
        a_hash_including(
          id: be_an_instance_of(Integer),
          errors: [],
          start_time_seconds: be_within(0.001).of(6.709509878),
          tags: [
            a_hash_including(text: 'Birb'),
            a_hash_including(id: machine_generated_tag.id,
              text: 'machine generated')
          ]
        ),
        a_hash_including(
          id: be_an_instance_of(Integer),
          errors: [],
          start_time_seconds: be_within(0.001).of(29.383026016),
          tags: [
            a_hash_including(text: 'donkey'),
            a_hash_including(id: machine_generated_tag.id,
              text: 'machine generated')
          ]
        )
      ],
      additional_tags: [machine_generated_tag]
    )

    events = AudioEvent.by_import(@audio_event_import.id)
    expect(events.count).to eq 2
    expect(events.all.to_a).to all(have_attributes(tags: include(machine_generated_tag)))
  end

  it 'can accept multiple additional tags' do
    create_import
    another_tag = create(:tag, text: 'They Cannot Crucify You If Your Hands Is In A Fist')
    submit(raven_example, commit: true, additional_tags: [machine_generated_tag, another_tag])
    assert_success(
      committed: true,
      name: raven_filename,
      imported_events: [
        a_hash_including(
          id: be_an_instance_of(Integer),
          errors: [],
          start_time_seconds: be_within(0.001).of(6.709509878),
          tags: a_collection_including(
            a_hash_including(text: 'Birb'),
            a_hash_including(id: machine_generated_tag.id, text: machine_generated_tag.text),
            a_hash_including(id: another_tag.id, text: another_tag.text)
          )
        ),
        a_hash_including(
          id: be_an_instance_of(Integer),
          errors: [],
          start_time_seconds: be_within(0.001).of(29.383026016),
          tags: a_collection_including(
            a_hash_including(text: 'donkey'),
            a_hash_including(id: machine_generated_tag.id, text: machine_generated_tag.text),
            a_hash_including(id: another_tag.id, text: another_tag.text)
          )
        )
      ],
      additional_tags: [machine_generated_tag, another_tag]
    )
  end

  stepwise 'can accept multiple files after creation' do
    step 'create import with no events' do
      create_import
    end

    step 'send a file of events to import' do
      submit(raven_example)
    end

    step 'check for success' do
      assert_success(
        committed: true,
        name: raven_filename,
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
        ],
        additional_tags: []
      )
    end

    step 'send another file but do not commit' do
      submit(generic_example, commit: false, additional_tags: [machine_generated_tag])
    end

    step 'check result' do
      assert_success(
        committed: false,
        name: 'generic_example.csv',
        imported_events: [
          a_hash_including(
            id: nil,
            errors: [],
            start_time_seconds: be_within(0.001).of(123),
            tags: [
              a_hash_including(text: 'Birb'),
              a_hash_including(id: machine_generated_tag.id, text: machine_generated_tag.text)
            ]
          )
        ],
        additional_tags: [machine_generated_tag]
      )
    end

    step 'and check the actual event count remains unchanged' do
      expect(AudioEvent.by_import(@audio_event_import.id).count).to eq 2
    end

    step 'send another file' do
      submit(generic_example, additional_tags: [machine_generated_tag])
    end

    step 'check for updated events' do
      assert_success(
        committed: true,
        name: 'generic_example.csv',
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
        ],
        additional_tags: [machine_generated_tag]
      )
    end

    step '3 Audio events should have been registered' do
      events = AudioEvent.by_import(@audio_event_import.id)
      expect(events.count).to eq 3
    end
  end
end
