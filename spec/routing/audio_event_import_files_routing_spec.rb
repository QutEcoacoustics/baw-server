# frozen_string_literal: true

describe RegionsController do
  describe 'routing' do
    it {
      expect(get('audio_event_imports/2/files')).to route_to(
        'audio_event_import_files#index',
        format: 'json',
        audio_event_import_id: '2'
      )
    }

    it {
      expect(post('audio_event_imports/2/files')).to route_to(
        'audio_event_import_files#create',
        format: 'json',
        audio_event_import_id: '2'
      )
    }

    it {
      expect(get('audio_event_imports/2/files/new')).to route_to(
        'audio_event_import_files#new',
        format: 'json',
        audio_event_import_id: '2'
      )
    }

    it {
      expect(get('audio_event_imports/2/files/1')).to route_to(
        'audio_event_import_files#show',
        format: 'json',
        id: '1',
        audio_event_import_id: '2'
      )
    }

    # immutable
    it {
      expect(put('audio_event_imports/2/files/1')).not_to route_to(
        'audio_event_import_files#update',
        format: 'json',
        id: '1',
        audio_event_import_id: '2'
      )
    }

    # immutable
    it {
      expect(patch('audio_event_imports/2/files/1')).not_to route_to(
        'audio_event_import_files#update',
        format: 'json',
        id: '1',
        audio_event_import_id: '2'
      )
    }

    it {
      expect(delete('audio_event_imports/2/files/1')).to route_to(
        'audio_event_import_files#destroy',
        format: 'json',
        id: '1',
        audio_event_import_id: '2'
      )
    }

    it_behaves_like 'our api routing patterns', 'audio_event_imports/2/files', 'audio_event_import_files', [:filterable], {
      audio_event_import_id: '2'
    }
  end
end
