require 'spec_helper'

describe AudioRecordingsController do
  describe :routing do

    it { expect(get('/projects/1/sites/2/audio_recordings/check_uploader/4')).to route_to('audio_recordings#check_uploader', project_id: '1', site_id: '2', uploader_id: '4', format: 'json') }

    it { expect(get('/projects/1/sites/2/audio_recordings')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings') }
    it { expect(post('/projects/1/sites/2/audio_recordings')).to route_to('audio_recordings#create', project_id: '1', site_id: '2', format: 'json') }
    it { expect(get('/projects/1/sites/2/audio_recordings/new')).to route_to('audio_recordings#new', project_id: '1', site_id: '2', format: 'json') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3')).to route_to('errors#route_error', requested_route:'projects/1/sites/2/audio_recordings/3' ) }

    it { expect(get('audio_recordings/3')).to route_to('audio_recordings#show', id: '3', format: 'json') }
    it { expect(get('audio_recordings/new')).to route_to('audio_recordings#new', format: 'json') }
    it { expect(put('/audio_recordings/3/update_status')).to route_to('audio_recordings#update_status', :id => '3', format: 'json') }

  end
end