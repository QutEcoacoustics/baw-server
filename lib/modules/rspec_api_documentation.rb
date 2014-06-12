# make sure head requests get the parameters as a query string, not
# in the body
if ENV['RAILS_ENV'] == 'test'
  require 'rspec/core/formatters/base_formatter'
  require 'rack/utils'
  require 'rack/test/utils'

  module RspecApiDocumentation::DSL
    module Endpoint
      def do_request(extra_params = {})
        @extra_params = extra_params

        params_or_body = nil
        path_or_query = path

        if (method == :get || method == :head) && !query_string.blank?
          path_or_query += "?#{query_string}"
        else
          params_or_body = respond_to?(:raw_post) ? raw_post : params
        end

        rspec_api_documentation_client.send(method, path_or_query, params_or_body, headers)
      end
    end
  end

# need to patch json writing to ensure binary response_body
# does not get included.
  module RspecApiDocumentation
    module Writers
      module Formatter

        def self.to_json(object)
          json_obj = object.as_json

          if json_obj.include? :requests
            json_obj.requests.each do |request|
              check_non_ascii_printable = request.response_body =~ /[^[:print:]]/
              unless check_non_ascii_printable.nil?
                request[:response_body] = 'Cannot be printed.'
              end
            end
          end

          JSON.pretty_generate(json_obj)
        end

      end
    end
  end

end