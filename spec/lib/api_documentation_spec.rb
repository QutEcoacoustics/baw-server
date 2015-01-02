# require 'spec_helper'
#
# describe 'rspec api documentation' do
#
#   # This test can only be run if the API tests are also running.
#   it 'tests all routes' do
#     Rails.application.reload_routes!
#     route_check = Api::CustomRoutes.new(routes: Rails.application.routes.routes, world: RSpec::world)
#
#     route_check.missing_docs.should == Set.new
#   end
#
# end