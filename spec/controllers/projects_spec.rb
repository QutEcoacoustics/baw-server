require 'rails_helper'
require 'rspec/mocks'

describe ProjectsController do
  describe 'archivable' do
    before(:each) do
      # see https://github.com/plataformatec/devise/wiki/How-To:-Test-controllers-with-Rails-3-and-4-(and-RSpec)
      @request.env['devise.mapping'] = Devise.mappings[:admin]
      admin = FactoryGirl.create(:admin)
      sign_in(admin, scope: :user) # sign_in(scope, resource)
    end

    it_behaves_like :a_delete_api_call, Project, :allow_archive #, :allow_delete

    context 'archivable with associations' do
      create_entire_hierarchy

      let(:delete_api_model){
        project
      }

      it_behaves_like :a_delete_api_call, Project, :allow_archive, :allow_delete
    end

  end
end