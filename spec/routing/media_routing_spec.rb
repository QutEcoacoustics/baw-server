# frozen_string_literal: true

require 'rails_helper'

describe MediaController, type: :routing do
  describe :routing do
    # also used by client
    it { expect(get('/projects/1/sites/2/audio_recordings/3/media.json')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/media', format: 'json') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/media.png')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/media', format: 'png') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/media.mp3')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/media', format: 'mp3') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/media')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/media') }

    it { expect(get('/audio_recordings/3/media.json')).to route_to('media#show', audio_recording_id: '3', format: 'json') }
    it { expect(get('/audio_recordings/3/media.json?start_offset=1&end_offset=2')).to route_to('media#show', audio_recording_id: '3', format: 'json', start_offset: '1', end_offset: '2') }
    it { expect(get('/audio_recordings/3/media.png')).to route_to('media#show', audio_recording_id: '3', format: 'png') }
    it { expect(get('/audio_recordings/3/media.mp3')).to route_to('media#show', audio_recording_id: '3', format: 'mp3') }
    it { expect(get('/audio_recordings/3/media')).to route_to('errors#route_error', requested_route: 'audio_recordings/3/media') }

    it { expect(head('/projects/1/sites/2/audio_recordings/3/media.json')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/media', format: 'json') }
    it { expect(head('/projects/1/sites/2/audio_recordings/3/media.png')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/media', format: 'png') }
    it { expect(head('/projects/1/sites/2/audio_recordings/3/media.mp3')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/media', format: 'mp3') }
    it { expect(head('/projects/1/sites/2/audio_recordings/3/media')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/media') }

    it { expect(head('/audio_recordings/3/media.json')).to route_to('media#show', audio_recording_id: '3', format: 'json') }
    it { expect(head('/audio_recordings/3/media.json?start_offset=1&end_offset=2')).to route_to('media#show', audio_recording_id: '3', format: 'json', start_offset: '1', end_offset: '2') }
    it { expect(head('/audio_recordings/3/media.png')).to route_to('media#show', audio_recording_id: '3', format: 'png') }
    it { expect(head('/audio_recordings/3/media.mp3')).to route_to('media#show', audio_recording_id: '3', format: 'mp3') }
    it { expect(head('/audio_recordings/3/media')).to route_to('errors#route_error', requested_route: 'audio_recordings/3/media') }

    # original audio download routes
    it { expect(get('/audio_recordings/3/original')).to route_to('media#original', audio_recording_id: '3', format: false) }
  end
end
