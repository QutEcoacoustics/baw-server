#require 'spec_helper'
#
#describe ProjectsController do
#
#  # This should return the minimal set of attributes required to create a valid
#  # Project. As you add validations to Project, be sure to
#  # adjust the attributes here as well.
#  let(:valid_attributes) { { 'name' => 'MyString' } }
#
#  # This should return the minimal set of values that should be in the session
#  # in order to pass any filters (e.g. authentication) defined in
#  # ProjectsController. Be sure to keep this updated too.
#  let(:valid_session) { {} }
#
#  describe 'GET index' do
#    it 'assigns all projects as @projects' do
#      project = Project.create! valid_attributes
#      get :index, {}, valid_session
#      assigns(:projects).should eq([project])
#    end
#  end
#
#  describe 'GET show' do
#    it 'assigns the requested project as @project' do
#      project = Project.create! valid_attributes
#      get :show, {:id => project.to_param}, valid_session
#      assigns(:project).should eq(project)
#    end
#  end
#
#  describe 'GET new' do
#    it 'assigns a new project as @project' do
#      get :new, {}, valid_session
#      assigns(:project).should be_a_new(Project)
#    end
#  end
#
#  describe 'GET edit' do
#    it 'assigns the requested project as @project' do
#      project = Project.create! valid_attributes
#      get :edit, {:id => project.to_param}, valid_session
#      assigns(:project).should eq(project)
#    end
#  end
#
#  describe 'POST create' do
#    describe 'with valid params' do
#      it 'creates a new Project' do
#        expect {
#          post :create, {:project => valid_attributes}, valid_session
#        }.to change(Project, :count).by(1)
#      end
#
#      it 'assigns a newly created project as @project' do
#        post :create, {:project => valid_attributes}, valid_session
#        assigns(:project).should be_a(Project)
#        assigns(:project).should be_persisted
#      end
#
#      it 'redirects to the created project' do
#        post :create, {:project => valid_attributes}, valid_session
#        response.should redirect_to(Project.last)
#      end
#    end
#
#    describe 'with invalid params' do
#      it 'assigns a newly created but unsaved project as @project' do
#        # Trigger the behavior that occurs when invalid params are submitted
#        Project.any_instance.stub(:save).and_return(false)
#        post :create, {:project => { 'description' => 'invalid value' }}, valid_session
#        assigns(:project).should be_a_new(Project)
#      end
#
#      it 're-renders the 'new' template' do
#        # Trigger the behavior that occurs when invalid params are submitted
#        Project.any_instance.stub(:save).and_return(false)
#        post :create, {:project =>  { 'description' => 'invalid value' }}, valid_session
#        response.should render_template('new')
#      end
#    end
#  end
#
#  describe 'PUT update' do
#    describe 'with valid params' do
#      it 'updates the requested project' do
#        project = Project.create! valid_attributes
#        # Assuming there are no other projects in the database, this
#        # specifies that the Project created on the previous line
#        # receives the :update_attributes message with whatever params are
#        # submitted in the request.
#        Project.any_instance.should_receive(:update_attributes).with({ 'name' => 'MyNewString' })
#        put :update, {:id => project.to_param, :project => { 'name' => 'MyNewString' }}, valid_session
#      end
#
#      it 'assigns the requested project as @project' do
#        project = Project.create! valid_attributes
#        put :update, {:id => project.to_param, :project => valid_attributes}, valid_session
#        assigns(:project).should eq(project)
#      end
#
#      it 'redirects to the project' do
#        project = Project.create! valid_attributes
#        put :update, {:id => project.to_param, :project => valid_attributes}, valid_session
#        response.should redirect_to(project)
#      end
#    end
#
#    describe 'with invalid params' do
#      it 'assigns the project as @project' do
#        project = Project.create! valid_attributes
#        # Trigger the behavior that occurs when invalid params are submitted
#        Project.any_instance.stub(:save).and_return(false)
#        put :update, {:id => project.to_param, :project => { 'name' => 'invalid value' }}, valid_session
#        assigns(:project).should eq(project)
#      end
#
#      it 're-renders the 'edit' template' do
#        project = Project.create! valid_attributes
#        # Trigger the behavior that occurs when invalid params are submitted
#        Project.any_instance.stub(:save).and_return(false)
#        put :update, {:id => project.to_param, :project => { 'name' => 'invalid value' }}, valid_session
#        response.should render_template('edit')
#      end
#    end
#  end
#
#  describe 'DELETE destroy' do
#    it 'destroys the requested project' do
#      project = Project.create! valid_attributes
#      expect {
#        delete :destroy, {:id => project.to_param}, valid_session
#      }.to change(Project, :count).by(-1)
#    end
#
#    it 'redirects to the projects list' do
#      project = Project.create! valid_attributes
#      delete :destroy, {:id => project.to_param}, valid_session
#      response.should redirect_to(projects_url)
#    end
#  end
#
#end
