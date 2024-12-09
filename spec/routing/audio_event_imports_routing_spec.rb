# frozen_string_literal: true

describe AudioEventImportsController do
  describe 'routing' do
    it { expect(get('audio_event_imports')).to route_to('audio_event_imports#index', format: 'json') }
    it { expect(post('audio_event_imports')).to route_to('audio_event_imports#create', format: 'json') }
    it { expect(get('audio_event_imports/new')).to route_to('audio_event_imports#new', format: 'json') }
    it { expect(get('audio_event_imports/1')).to route_to('audio_event_imports#show', format: 'json', id: '1') }
    it { expect(put('audio_event_imports/1')).to route_to('audio_event_imports#update', format: 'json', id: '1') }
    it { expect(patch('audio_event_imports/1')).to route_to('audio_event_imports#update', format: 'json', id: '1') }
    it { expect(delete('audio_event_imports/1')).to route_to('audio_event_imports#destroy', format: 'json', id: '1') }

    it_behaves_like 'our api routing patterns', 'audio_event_imports', 'audio_event_imports', [:filterable, :archivable]
  end
end
