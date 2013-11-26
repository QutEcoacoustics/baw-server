#require 'spec_helper'
#
#describe AudioEventsController do
#  describe 'GET #index' do
#    before(:each) do
#      @response_body = json get: :index
#    end
#
#    it_should_behave_like  :an_idempotent_api_call, AudioEvent
#  end
#
#  describe 'GET #show' do
#    before(:each) do
#      @item = create(:audio_event)
#      @response_body = json({ get: :show, id: @item.id })
#    end
#
#    it_should_behave_like  :an_idempotent_api_call, AudioEvent, false
#  end
#
#  describe 'GET #new' do
#    before(:each) do
#      @response_body = json get: :new
#      @expected_hash = {
#          :id => nil,
#          :audio_recording => nil,
#          :audio_recording_id => nil,
#          :end_time_seconds => nil,
#          :high_frequency_hertz => nil,
#          :is_reference => false,
#          :low_frequency_hertz => nil,
#          :start_time_seconds => nil,
#          :tags => [],
#          :updated_at => nil,
#          :created_at => nil,
#          :updater_id => nil,
#          :creator_id => nil
#      }
#    end
#
#    it_should_behave_like :a_new_api_call, AudioEvent
#  end
#
#  describe 'POST #create' do
#    context 'with valid attributes' do
#      before(:each) do
#        @initial_count = AudioEvent.count
#        test = convert_model(:create, :audio_event, build(:audio_event))
#        @response_body = json(test)
#      end
#
#      it_should_behave_like :a_valid_create_api_call, AudioEvent
#    end
#
#    context 'with invalid attributes' do
#      before(:each) do
#        @initial_count = AudioEvent.count
#        test = convert_model(:create, :audio_event, nil)
#        @response_body = json(test)
#      end
#
#      it_should_behave_like :an_invalid_create_api_call, AudioEvent, {:audio_recording=>["can't be blank"], :start_time_seconds=>["can't be blank", 'is not a number'], :low_frequency_hertz=>["can't be blank", 'is not a number']}
#    end
#  end
#
#  describe 'PUT #update' do
#    context 'with valid attributes' do
#      before(:each) do
#        @changed = create(:audio_event)
#        @changed.start_time_seconds = 500
#        @changed.end_time_seconds = 600
#        test = convert_model(:update, :audio_event, @changed)
#        @response_body = json(test)
#      end
#
#      it_should_behave_like :a_valid_update_api_call, AudioEvent, :start_time_seconds
#    end
#
#    context 'with invalid attributes' do
#      before(:each) do
#        @initial = create(:audio_event)
#        @old_value = @initial.start_time_seconds
#        @initial.start_time_seconds = -10.0
#        test = convert_model(:update, :audio_event, @initial)
#        @response_body = json(test)
#      end
#
#      it_should_behave_like :an_invalid_update_api_call, AudioEvent, :start_time_seconds, {:start_time_seconds => ['must be greater than or equal to 0']}
#    end
#  end
#
#  describe 'DELETE #destory' do
#    it_should_behave_like :a_delete_api_call, AudioEvent, :allow_delete , :allow_archive
#  end
#
#end
#
