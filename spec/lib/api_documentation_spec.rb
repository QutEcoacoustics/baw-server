## Enable this when I've figured out how to specify the routes I expect to be covered by rspec_api_documentation tests
# require 'spec_helper'
#
# describe 'rspec api documentation' do
#
#   # This test can only be run if the API tests are also running.
#   it 'tests all routes' do
#     Rails.application.reload_routes!
#     route_check = Api::CustomRoutes.new(routes: Rails.application.routes.routes, world: RSpec::world)
#
#     missing = route_check.missing_docs
#     expect(missing).to eq(Set.new), "expected empty set, got #{missing.size}: #{missing.map{ |m| "'#{m.to_s}'"}.join(', ')}"
#   end
#
# end