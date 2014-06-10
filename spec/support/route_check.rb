# from  https://gist.github.com/kayline/8868438
# blog post http://pivotallabs.com/tested-tests-lately/

require File.join(File.dirname(__FILE__),'route_wrapper')

class RouteCheck
  attr_reader :routes, :world

  def initialize(routes= nil, world= nil)
    @routes = routes
    @world = world
  end

  def filtered_routes
    collect_routes do |route|
      next if route.internal?
      next if route.verb.blank?
      next if route.controller =~ /^devise.*/
      next if route.controller =~ /^docs.*/
      next if route.controller == 'users'
      next if route.controller == 'authentication_jig'
      next if route.controller == 'invitations'
      next if route.controller == 'admin'
      next if route.controller == 'index'
      route
    end.compact
  end

  def api_specs
    world.
        example_groups.
        map(&:descendants).
        flatten.
        reject { |g| g.metadata.fetch(:api_doc_dsl, :not_found) == :not_found }.
        reject { |g| g.metadata.fetch(:method, :not_found) == :not_found }
  end

  def missing_docs
    existing_routes = Set.new(matchable_routes(filtered_routes))
    existing_route_specs = Set.new(matchable_specs(api_specs))

    existing_routes - existing_route_specs
  end

  private
  def matchable_routes(routes)
    routes.collect do |r|
      ::Route.new(r.verb, r.path[/\/[^( ]+/])
    end.compact
  end

  def matchable_specs(specs)
    specs.map do |spec|
      ::Route.new(spec.metadata[:method], spec.metadata[:route])
    end
  end

  def collect_routes
    routes.collect do |route|
      route = yield ActionDispatch::Routing::RouteWrapper.new(route)
    end
  end
end

class ::Route < Struct.new(:method, :path)
  def eql? other
    self.hash == other.hash
  end

  def == other
    method.to_s.downcase == other.method.to_s.downcase and path.downcase == other.path.downcase
  end

  def hash
    method.to_s.downcase.hash + path.downcase.hash
  end
end