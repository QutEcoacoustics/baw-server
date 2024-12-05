# frozen_string_literal: true

module Api
  # Enables custom routes to be created.
  class CustomRoutes
    attr_reader :routes, :world

    # Create a new +CustomRoutes+.
    # @see http://pivotallabs.com/tested-tests-lately/
    # @see https://gist.github.com/kayline/8868438
    def initialize(routes: nil, world: nil)
      # usage:
      # custom_routes = CustomRoutes.new(routes: Rails.application.routes.routes, world: RSpec::world)
      @routes = routes
      @world = world
    end

    def filtered_routes
      collect_routes { |route|
        next if route.internal?
        next if route.engine?
        next if route.verb.blank?

        guessed_controller_name = "#{route.controller.camelize}Controller".safe_constantize
        next if !guessed_controller_name.nil? && guessed_controller_name.superclass.name == 'DeviseController'

        # next if route.controller =~ /^docs.*/
        # next if route.controller == "users"
        # next if route.controller == "authentication_jig"
        # next if route.controller == "invitations"
        # next if route.controller == "admin"
        # next if route.controller == "index"
        route
      }.compact
    end

    def api_specs
      world
        .example_groups
        .map(&:descendants)
        .flatten
        .reject { |g| g.metadata.fetch(:api_doc_dsl, :not_found) == :not_found }
        .reject { |g| g.metadata.fetch(:method, :not_found) == :not_found }
    end

    def missing_docs
      existing_routes = Set.new(matchable_routes(filtered_routes))
      existing_route_specs = Set.new(matchable_specs(api_specs))

      existing_routes - existing_route_specs
    end

    private

    def matchable_routes(routes)
      routes.collect { |audio_recording|
        method = audio_recording.verb
        method = '' if method.blank?

        path = audio_recording.path[%r{/[^( ]*}]
        path = '' if path.blank?

        ::Route.new(method, path)
      }.compact
    end

    def matchable_specs(specs)
      specs.map do |spec|
        ::Route.new(spec.metadata[:method], spec.metadata[:route])
      end
    end

    def collect_routes
      routes.collect do |route|
        yield ActionDispatch::Routing::RouteWrapper.new(route)
      end
    end
  end

  ::Route = Struct.new(:method, :path) do
    def eql?(other)
      hash == other.hash
    end

    def ==(other)
      method.to_s.downcase == other.method.to_s.downcase && path.downcase == other.path.downcase
    end

    def hash
      method.to_s.downcase.hash + path.downcase.hash
    end

    def to_s
      "#{method} #{path}"
    end
  end
end
