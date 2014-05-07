require 'spec_helper'

describe MediaController do
  describe :routing do

    it { expect(get('/projects/1/sites/2/audio_recordings/3/media.json')).to route_to('media#show', project_id: '1', site_id: '2', audio_recording_id: '3', format: 'json') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/media.png')).to route_to('media#show', project_id: '1', site_id: '2', audio_recording_id: '3', format: 'png') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/media.mp3')).to route_to('media#show', project_id: '1', site_id: '2', audio_recording_id: '3', format: 'mp3') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/media')).to route_to('errors#routing', requested_route: 'projects/1/sites/2/audio_recordings/3/media') }

    it { expect(get('/audio_recordings/3/media.json')).to route_to('media#show', audio_recording_id: '3', format: 'json') }
    it { expect(get('/audio_recordings/3/media.png')).to route_to('media#show', audio_recording_id: '3', format: 'png') }
    it { expect(get('/audio_recordings/3/media.mp3')).to route_to('media#show', audio_recording_id: '3', format: 'mp3') }
    it { expect(get('/audio_recordings/3/media')).to route_to('errors#routing', requested_route: 'audio_recordings/3/media') }

  end
end

