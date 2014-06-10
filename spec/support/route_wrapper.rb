require 'delegate'
require 'active_support/core_ext/string/strip'

module ActionDispatch
  module Routing
    class RouteWrapper < SimpleDelegator
      def endpoint
        rack_app ? rack_app.inspect : "#{controller}##{action}"
      end

      def constraints
        requirements.except(:controller, :action)
      end

      def rack_app(app = self.app)
        @rack_app ||= begin
          class_name = app.class.name.to_s
          if class_name == "ActionDispatch::Routing::Mapper::Constraints"
            rack_app(app.app)
          elsif ActionDispatch::Routing::Redirect === app || class_name !~ /^ActionDispatch::Routing/
            app
          end
        end
      end

      def verb
        super.source.gsub(/[$^]/, '')
      end

      def path
        super.spec.to_s
      end

      def name
        super.to_s
      end

      def regexp
        __getobj__.path.to_regexp
      end

      def json_regexp
        str = regexp.inspect.
            sub('\\A', '^').
            sub('\\Z', '$').
            sub('\\z', '$').
            sub(/^\//, '').
            sub(/\/[a-z]*$/, '').
            gsub(/\(\?#.+\)/, '').
            gsub(/\(\?-\w+:/, '(').
            gsub(/\s/, '')
        Regexp.new(str).source
      end

      def reqs
        @reqs ||= begin
          reqs = endpoint
          reqs += " #{constraints.to_s}" unless constraints.empty?
          reqs
        end
      end

      def controller
        requirements[:controller] || ':controller'
      end

      def action
        requirements[:action] || ':action'
      end

      def internal?
        controller.to_s =~ %r{\Arails/(info|mailers|welcome)} || path =~ %r{\A#{Rails.application.config.assets.prefix}\z}
      end

      def engine?
        rack_app && rack_app.respond_to?(:routes)
      end
    end
  end
end
