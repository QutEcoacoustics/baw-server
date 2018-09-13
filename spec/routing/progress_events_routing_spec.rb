require 'rails_helper'

describe ProgressEventsController, :type => :routing do
  describe :routing do

    describe 'create with valid params' do
      it { expect(post('/progress_events')).to route_to('progress_events#create', format: 'json') }
    end

    describe 'create_by_dataset_item_params with valid params (integer offsets)' do
      it { expect(post('/datasets/1/progress_events/audio_recordings/2/start/3/end/4')).to route_to('progress_events#create_by_dataset_item_params', dataset_id: '1', audio_recording_id: '2', start_time_seconds: '3', end_time_seconds: '4', format: 'json') }
    end

    describe 'create_by_dataset_item_params with valid params (offsets 1 decimal place)' do
      it { expect(post('/datasets/1/progress_events/audio_recordings/2/start/3.0/end/4.0')).to route_to('progress_events#create_by_dataset_item_params', dataset_id: '1', audio_recording_id: '2', start_time_seconds: '3.0', end_time_seconds: '4.0', format: 'json') }
    end

    describe 'create_by_dataset_item_params with valid params (offsets 5 decimal places)' do
      it { expect(post('/datasets/1/progress_events/audio_recordings/2/start/3.12345/end/4.12345')).to route_to('progress_events#create_by_dataset_item_params', dataset_id: '1', audio_recording_id: '2', start_time_seconds: '3.12345', end_time_seconds: '4.12345', format: 'json') }
    end

  end
end