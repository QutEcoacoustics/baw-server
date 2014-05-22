require 'spec_helper'

# describe AudioEventsController do
#   render_views
#
#   context 'csv download' do
#
#     #header 'Accept', 'application/json'
#     #header 'Content-Type', 'application/json'
#
#     get '/audio_recordings/:audio_recording_id/audio_events/download' do
#       parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
#       let(:authentication_token) { writer_token }
#       standard_request('CSV AUDIO RECORDING (as writer)', 200, '0/start_time_seconds', true)
#     end
#
#     get '/audio_recordings/:audio_recording_id/audio_events/download' do
#       parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
#       let(:authentication_token) { reader_token }
#       standard_request('CSV AUDIO RECORDING (as reader)', 200, '0/start_time_seconds', true)
#     end
#
#     get '/audio_recordings/:audio_recording_id/audio_events/download' do
#       parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
#       let(:authentication_token) { admin_token }
#       standard_request('CSV AUDIO RECORDING (as admin)', 200, '0/start_time_seconds', true)
#     end
#
#     get '/audio_recordings/:audio_recording_id/audio_events/download' do
#       parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
#       let(:authentication_token) { unconfirmed_token }
#       standard_request('CSV AUDIO RECORDING (as unconfirmed user)', 401, nil, true)
#     end
#
#     get '/projects/:project_id/audio_events/download' do
#       parameter :project_id, 'Requested project id (in path/route)', required: true
#       let(:authentication_token) { writer_token }
#       standard_request('CSV PROJECT (as writer)', 200, '0/start_time_seconds', true)
#     end
#
#     get '/projects/:project_id/audio_events/download' do
#       parameter :project_id, 'Requested project id (in path/route)', required: true
#       let(:authentication_token) { reader_token }
#       standard_request('CSV PROJECT (as reader)', 200, '0/start_time_seconds', true)
#     end
#
#     get '/projects/:project_id/audio_events/download' do
#       parameter :project_id, 'Requested project id (in path/route)', required: true
#       let(:authentication_token) { admin_token }
#       standard_request('CSV PROJECT (as admin)', 200, '0/start_time_seconds', true)
#     end
#
#     get '/projects/:project_id/audio_events/download' do
#       parameter :project_id, 'Requested project id (in path/route)', required: true
#       let(:authentication_token) { unconfirmed_token }
#       standard_request('CSV PROJECT (as unconfirmed user)', 401, nil, true)
#     end
#
#     get '/projects/:project_id/sites/:site_id/audio_events/download' do
#       parameter :project_id, 'Requested project id (in path/route)', required: true
#       parameter :site_id, 'Requested site id (in path/route)', required: true
#       let(:authentication_token) { writer_token }
#       standard_request('CSV SITE (as writer)', 200, '0/start_time_seconds', true)
#     end
#
#     get '/projects/:project_id/audio_events/download' do
#       parameter :project_id, 'Requested project id (in path/route)', required: true
#       parameter :site_id, 'Requested site id (in path/route)', required: true
#       let(:authentication_token) { reader_token }
#       standard_request('CSV SITE (as reader)', 200, '0/start_time_seconds', true)
#     end
#
#     get '/projects/:project_id/audio_events/download' do
#       parameter :project_id, 'Requested project id (in path/route)', required: true
#       parameter :site_id, 'Requested site id (in path/route)', required: true
#       let(:authentication_token) { admin_token }
#       standard_request('CSV SITE (as admin)', 200, '0/start_time_seconds', true)
#     end
#
#     get '/projects/:project_id/audio_events/download' do
#       parameter :project_id, 'Requested project id (in path/route)', required: true
#       parameter :site_id, 'Requested site id (in path/route)', required: true
#       let(:authentication_token) { unconfirmed_token }
#       standard_request('CSV SITE (as unconfirmed user)', 401, nil, true)
#     end
#   end
# end


describe AudioEventsController do

  # This should return the minimal set of attributes required to create a valid
  # UserAccount. As you add validations to UserAccount, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) { {} }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # UserAccountsController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  let(:valid_routing) { {format: 'csv', project_id: permission.project.id } }

  let(:permission) { FactoryGirl.create(:write_permission) }

  let(:writer_token) { "Token token=\"#{permission.user.authentication_token}\"" }

  describe 'GET download' do

    it 'should work for a basic request' do
      request.headers['Authorization'] = writer_token
      sign_in :user, permission.user
      get :download, valid_routing, valid_session
      #assigns(:formatted_annotations).should eq([permission.project.sites[0].audio_recordings[0].audio_events[0]])
      expect(response.status).to eq(200)
      expect(response.body).to match /Listing widgets/m
    end
  end


#
# describe "GET index" do
#    it "assigns all audio_event as @user_accounts" do
#      audio_event = AudioEvent.create! valid_attributes
#      get :index, {}, valid_session
#      assigns(:audio_event).should eq([audio_event])
#    end
# end
#
# describe "GET show" do
#    it "assigns the requested audio_event as @audio_event" do
#      audio_event = AudioEvent.create! valid_attributes
#      get :show, {:id => audio_event.to_param}, valid_session
#      assigns(:audio_event).should eq(audio_event)
#    end
# end
#
# describe "GET new" do
#    it "assigns a new audio_event as @audio_event" do
#      get :new, {}, valid_session
#      assigns(:audio_event).should be_a_new(AudioEvent)
#    end
# end
#
# describe "GET edit" do
#    it "assigns the requested user_account as @user_account" do
#      user_account = UserAccount.create! valid_attributes
#      get :edit, {:id => user_account.to_param}, valid_session
#      assigns(:user_account).should eq(user_account)
#    end
# end
#
# describe "POST create" do
#    describe "with valid params" do
#      it "creates a new UserAccount" do
#        expect {
#          post :create, {:user_account => valid_attributes}, valid_session
#        }.to change(UserAccount, :count).by(1)
#      end
#
#      it "assigns a newly created user_account as @user_account" do
#        post :create, {:user_account => valid_attributes}, valid_session
#        assigns(:user_account).should be_a(UserAccount)
#        assigns(:user_account).should be_persisted
#      end
#
#      it "redirects to the created user_account" do
#        post :create, {:user_account => valid_attributes}, valid_session
#        response.should redirect_to(UserAccount.last)
#      end
#    end
#
#    describe "with invalid params" do
#      it "assigns a newly created but unsaved user_account as @user_account" do
#        # Trigger the behavior that occurs when invalid params are submitted
#        UserAccount.any_instance.stub(:save).and_return(false)
#        post :create, {:user_account => {  }}, valid_session
#        assigns(:user_account).should be_a_new(UserAccount)
#      end
#
#      it "re-renders the 'new' template" do
#        # Trigger the behavior that occurs when invalid params are submitted
#        UserAccount.any_instance.stub(:save).and_return(false)
#        post :create, {:user_account => {  }}, valid_session
#        response.should render_template("new")
#      end
#    end
# end
#
# describe "PUT update" do
#    describe "with valid params" do
#      it "updates the requested user_account" do
#        user_account = UserAccount.create! valid_attributes
#        # Assuming there are no other user_accounts in the database, this
#        # specifies that the UserAccount created on the previous line
#        # receives the :update_attributes message with whatever params are
#        # submitted in the request.
#        UserAccount.any_instance.should_receive(:update_attributes).with({ "these" => "params" })
#        put :update, {:id => user_account.to_param, :user_account => { "these" => "params" }}, valid_session
#      end
#
#      it "assigns the requested user_account as @user_account" do
#        user_account = UserAccount.create! valid_attributes
#        put :update, {:id => user_account.to_param, :user_account => valid_attributes}, valid_session
#        assigns(:user_account).should eq(user_account)
#      end
#
#      it "redirects to the user_account" do
#        user_account = UserAccount.create! valid_attributes
#        put :update, {:id => user_account.to_param, :user_account => valid_attributes}, valid_session
#        response.should redirect_to(user_account)
#      end
#    end
#
#    describe "with invalid params" do
#      it "assigns the user_account as @user_account" do
#        user_account = UserAccount.create! valid_attributes
#        # Trigger the behavior that occurs when invalid params are submitted
#        UserAccount.any_instance.stub(:save).and_return(false)
#        put :update, {:id => user_account.to_param, :user_account => {  }}, valid_session
#        assigns(:user_account).should eq(user_account)
#      end
#
#      it "re-renders the 'edit' template" do
#        user_account = UserAccount.create! valid_attributes
#        # Trigger the behavior that occurs when invalid params are submitted
#        UserAccount.any_instance.stub(:save).and_return(false)
#        put :update, {:id => user_account.to_param, :user_account => {  }}, valid_session
#        response.should render_template("edit")
#      end
#    end
# end
#
# describe "DELETE destroy" do
#    it "destroys the requested user_account" do
#      user_account = UserAccount.create! valid_attributes
#      expect {
#        delete :destroy, {:id => user_account.to_param}, valid_session
#      }.to change(UserAccount, :count).by(-1)
#    end
#
#    it "redirects to the user_accounts list" do
#      user_account = UserAccount.create! valid_attributes
#      delete :destroy, {:id => user_account.to_param}, valid_session
#      response.should redirect_to(user_accounts_url)
#    end
# end

end
