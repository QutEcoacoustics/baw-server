require 'spec_helper'
require 'support/route_check'
require 'rspec_api_documentation/dsl'

# from  https://gist.github.com/kayline/8868438
# blog post http://pivotallabs.com/tested-tests-lately/

describe RouteCheck do
  let!(:application_routes) { ActionDispatch::Routing::RouteSet.new }
  let!(:route) { route_builder('GET', 'projects/lebowski', 'projects#lebowski', application_routes) }
  let!(:devise_route) { route_builder('POST', 'devise/users', 'users#bloop', application_routes)}
  let!(:internal_route) { route_builder('GET', '/assets', 'rails#get_info', application_routes) }


  describe '#filtered_routes' do
    let(:routes) { RouteCheck.new(routes: application_routes.routes) }
    let(:filtered_routes) { routes.filtered_routes }

    it 'includes all non-filtered routes' do
      filtered_routes.should == [route]
    end
  end

  describe '#api_specs' do
    subject(:route_check) { RouteCheck.new(world: world) }
    let(:configuration) { RSpec::Core::Configuration.new }
    let(:world) { RSpec::Core::World.new(configuration) }

    describe 'returns routes for tests found in the world' do
      context "when there are no examples" do
        it "is empty" do
          route_check.api_specs.should be_empty
        end
      end

      context "when there are non-API examples" do
        let(:regular_group) { RSpec::Core::ExampleGroup.describe("regular group") }
        let(:action_context) { resource_group.context("/path/to/api", {:api_doc_dsl => :endpoint, :method => "METHOD", :route => "/path/to/api"}) }
        let(:resource_group) do
          RSpec::Core::ExampleGroup.describe("resource group", {:api_doc_dsl => :resource}) do
            context "something different"
          end
        end

        before do
          world.register(regular_group)
          world.register(resource_group)
          action_context.register
        end

        it "returns only API test groups" do
          route_check.api_specs.should == [action_context]
        end
      end
    end
  end


  describe '#missing_docs' do
    subject(:route_check) { RouteCheck.new(routes: application_routes.routes, world: world) }

    let(:configuration) { RSpec::Core::Configuration.new }
    let(:world) { RSpec::Core::World.new(configuration) }
    let(:wrapped_route) { ActionDispatch::Routing::RouteWrapper.new(route) }
    let(:formatted_route) { ::Route.new(wrapped_route.verb.downcase, wrapped_route.path[/\/[^( ]+/]) }

    it 'detects routes for which no api test exists' do
      route_check.missing_docs.should == [formatted_route].to_set
    end

    it 'does not return routes for which an api spec exists' do
      group = RSpec::Core::ExampleGroup.describe("resource group", {:api_doc_dsl => :resource}) do
        context("/path/to/api", {:api_doc_dsl => :endpoint, :method => :get, :route => '/projects/lebowski'})
      end
      world.register(group)

      route_check.missing_docs.should be_empty
    end
  end

  def route_builder(method, path, action, route_set)
    scope = {:path_names=>{:new=>"new", :edit=>"edit"}}
    path = path
    name = path.split("/").last
    options = {:via => method, :to => action, :anchor => true, :as => name}
    mapping = ActionDispatch::Routing::Mapper::Mapping.new(route_set, scope, path, options)
    app, conditions, requirements, defaults, as, anchor = mapping.to_route


    route_set.add_route(app, conditions, requirements, defaults, as, anchor)
  end
end