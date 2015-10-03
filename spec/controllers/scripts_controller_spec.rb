#require 'rails_helper'
#
## This spec was generated by rspec-rails when you ran the scaffold generator.
## It demonstrates how one might use RSpec to specify the controller code that
## was generated by Rails when you ran the scaffold generator.
##
## It assumes that the implementation code is generated by the rails scaffold
## generator.  If you are using any extension libraries to generate different
## controller code, this generated spec may or may not pass.
##
## It only uses APIs available in rails and/or rspec-rails.  There are a number
## of tools you can use to make these specs even more expressive, but we're
## sticking to rails and rspec-rails APIs to keep things simple and stable.
##
## Compared to earlier versions of this generator, there is very limited use of
## stubs and message expectations in this spec.  Stubs are only used when there
## is no simpler way to get a handle on the object needed for the example.
## Message expectations are only used when there is no simpler way to specify
## that an instance is receiving a specific message.
#
#describe ScriptsController do
#
#  # This should return the minimal set of attributes required to create a valid
#  # Script. As you add validations to Script, be sure to
#  # adjust the attributes here as well.
#  let(:valid_attributes) { { "name" => "MyString" } }
#
#  # This should return the minimal set of values that should be in the session
#  # in order to pass any filters (e.g. authentication) defined in
#  # ScriptsController. Be sure to keep this updated too.
#  let(:valid_session) { {} }
#
#  describe "GET index" do
#    it "assigns all scripts as @scripts" do
#      script = Script.create! valid_attributes
#      get :index, {}, valid_session
#      assigns(:scripts).should eq([script])
#    end
#  end
#
#  describe "GET show" do
#    it "assigns the requested script as @script" do
#      script = Script.create! valid_attributes
#      get :show, {:id => script.to_param}, valid_session
#      assigns(:script).should eq(script)
#    end
#  end
#
#  describe "GET new" do
#    it "assigns a new script as @script" do
#      get :new, {}, valid_session
#      assigns(:script).should be_a_new(Script)
#    end
#  end
#
#  describe "GET edit" do
#    it "assigns the requested script as @script" do
#      script = Script.create! valid_attributes
#      get :edit, {:id => script.to_param}, valid_session
#      assigns(:script).should eq(script)
#    end
#  end
#
#  describe "POST create" do
#    describe "with valid params" do
#      it "creates a new Script" do
#        expect {
#          post :create, {:script => valid_attributes}, valid_session
#        }.to change(Script, :count).by(1)
#      end
#
#      it "assigns a newly created script as @script" do
#        post :create, {:script => valid_attributes}, valid_session
#        assigns(:script).should be_a(Script)
#        assigns(:script).should be_persisted
#      end
#
#      it "redirects to the created script" do
#        post :create, {:script => valid_attributes}, valid_session
#        response.should redirect_to(Script.last)
#      end
#    end
#
#    describe "with invalid params" do
#      it "assigns a newly created but unsaved script as @script" do
#        # Trigger the behavior that occurs when invalid params are submitted
#        Script.any_instance.stub(:save).and_return(false)
#        post :create, {:script => { "name" => "invalid value" }}, valid_session
#        assigns(:script).should be_a_new(Script)
#      end
#
#      it "re-renders the 'new' template" do
#        # Trigger the behavior that occurs when invalid params are submitted
#        Script.any_instance.stub(:save).and_return(false)
#        post :create, {:script => { "name" => "invalid value" }}, valid_session
#        response.should render_template("new")
#      end
#    end
#  end
#
#  describe "PUT update" do
#    describe "with valid params" do
#      it "updates the requested script" do
#        script = Script.create! valid_attributes
#        # Assuming there are no other scripts in the database, this
#        # specifies that the Script created on the previous line
#        # receives the :update_attributes message with whatever params are
#        # submitted in the request.
#        Script.any_instance.should_receive(:update_attributes).with({ "name" => "MyString" })
#        put :update, {:id => script.to_param, :script => { "name" => "MyString" }}, valid_session
#      end
#
#      it "assigns the requested script as @script" do
#        script = Script.create! valid_attributes
#        put :update, {:id => script.to_param, :script => valid_attributes}, valid_session
#        assigns(:script).should eq(script)
#      end
#
#      it "redirects to the script" do
#        script = Script.create! valid_attributes
#        put :update, {:id => script.to_param, :script => valid_attributes}, valid_session
#        response.should redirect_to(script)
#      end
#    end
#
#    describe "with invalid params" do
#      it "assigns the script as @script" do
#        script = Script.create! valid_attributes
#        # Trigger the behavior that occurs when invalid params are submitted
#        Script.any_instance.stub(:save).and_return(false)
#        put :update, {:id => script.to_param, :script => { "name" => "invalid value" }}, valid_session
#        assigns(:script).should eq(script)
#      end
#
#      it "re-renders the 'edit' template" do
#        script = Script.create! valid_attributes
#        # Trigger the behavior that occurs when invalid params are submitted
#        Script.any_instance.stub(:save).and_return(false)
#        put :update, {:id => script.to_param, :script => { "name" => "invalid value" }}, valid_session
#        response.should render_template("edit")
#      end
#    end
#  end
#
#  describe "DELETE destroy" do
#    it "destroys the requested script" do
#      script = Script.create! valid_attributes
#      expect {
#        delete :destroy, {:id => script.to_param}, valid_session
#      }.to change(Script, :count).by(-1)
#    end
#
#    it "redirects to the scripts list" do
#      script = Script.create! valid_attributes
#      delete :destroy, {:id => script.to_param}, valid_session
#      response.should redirect_to(scripts_url)
#    end
#  end
#
#end
