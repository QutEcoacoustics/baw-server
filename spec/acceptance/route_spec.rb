require 'spec_helper'
require 'support/route_check'

# from  https://gist.github.com/kayline/8868438
# blog post http://pivotallabs.com/tested-tests-lately/

# This test should go in the same folder with your API tests. It can only be run if the API tests are also running.
# describe 'APIs' do
#   it 'tests all routes' do
#     Rails.application.reload_routes!
#     route_check = RouteCheck.new(routes: Rails.application.routes.routes, world: RSpec::world)
#
#     route_check.missing_docs.should == Set.new
#   end
# end