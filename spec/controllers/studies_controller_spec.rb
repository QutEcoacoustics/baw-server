require 'rails_helper'

describe StudiesController, type: :controller do

  create_entire_hierarchy

  describe "GET #index" do
    it "returns http success" do
      get :index
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #show" do
    it "returns http success" do
      get :show, { :id => study.id}
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #filter" do
    it "returns http success" do
      get :filter
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #new" do
    it "returns http success" do
      get :new
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #create" do
    it "returns http success" do
      post :create, { study: { :dataset_id => dataset.id, :name => "something" }}
      expect(response).to have_http_status(401)
    end
  end

  describe "PUT #update" do
    it "returns http success" do
      put :update, { :id => study.id, :name => "something" }
      expect(response).to have_http_status(401)
    end
  end

end
