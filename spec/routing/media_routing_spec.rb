require 'spec_helper'

describe MediaController, :type => :routing do
  describe :routing do

    it { expect(get('/projects/1/sites/2/audio_recordings/3/media.json')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/media', format: 'json') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/media.png')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/media', format: 'png') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/media.mp3')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/media', format: 'mp3') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/media')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/media') }

    it { expect(get('/audio_recordings/3/media.json')).to route_to('media#show', audio_recording_id: '3', format: 'json') }
    it { expect(get('/audio_recordings/3/media.png')).to route_to('media#show', audio_recording_id: '3', format: 'png') }
    it { expect(get('/audio_recordings/3/media.mp3')).to route_to('media#show', audio_recording_id: '3', format: 'mp3') }
    it { expect(get('/audio_recordings/3/media')).to route_to('errors#route_error', requested_route: 'audio_recordings/3/media') }

  end
end