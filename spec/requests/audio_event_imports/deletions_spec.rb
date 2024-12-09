# frozen_string_literal: true

require_relative 'audio_event_import_context'

describe 'deletion' do
  include_context 'with audio event import context'

  before do
    create_import
    submit(raven_example, commit: true)

    expect(AudioEvent.count).to eq 2
    expect(ActiveStorage::Attachment.count).to eq 1
  end

  it_behaves_like 'an archivable route', {
    route: -> { "/audio_event_imports/#{@audio_event_import.id}" },
    instance: -> { @audio_event_import },
    baseline: lambda {
      expect(AudioEventImport.count).to eq 1
      expect(AudioEventImportFile.count).to eq 1
      expect(ActiveStorage::Attachment.count).to eq 1
      expect(AudioEvent.count).to eq 2
    },
    after_archive: lambda {
      expect(AudioEventImport.count).to eq 0
      expect(AudioEventImport.with_discarded.count).to eq 1

      # no soft-deletion for audio event import files
      expect(AudioEventImportFile.count).to eq 1

      expect(AudioEvent.count).to eq 0
      expect(AudioEvent.with_discarded.count).to eq 2

      expect(ActiveStorage::Attachment.count).to eq 1
    },
    after_delete: lambda {
      expect(AudioEventImport.count).to eq 0
      expect(AudioEventImport.with_discarded.count).to eq 0

      expect(AudioEventImportFile.count).to eq 0

      expect(AudioEvent.count).to eq 0
      expect(AudioEvent.with_discarded.count).to eq 0
    }
  }
end
