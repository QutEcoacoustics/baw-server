# frozen_string_literal: true

module RequestSpecHelpers
  # config.extend allows these methods to be used in describe/context groups
  module ExampleGroup
    # By default: exceptions are raised and not rescued by the error controller.
    # https://github.com/eliotsykes/rails-testing-toolbox/blob/master/error_responses.rb
    def render_error_responses
      around do |example|
        env_config = Rails.application.env_config
        original_show_exceptions = env_config['action_dispatch.show_exceptions']
        original_show_detailed_exceptions = env_config['action_dispatch.show_detailed_exceptions']
        env_config['action_dispatch.show_exceptions'] = :all
        env_config['action_dispatch.show_detailed_exceptions'] = false
        example.call
      ensure
        env_config['action_dispatch.show_exceptions'] = original_show_exceptions
        env_config['action_dispatch.show_detailed_exceptions'] = original_show_detailed_exceptions
      end
    end

    def with_csrf_protection
      around do |example|
        orig = ActionController::Base.allow_forgery_protection

        begin
          ActionController::Base.allow_forgery_protection = true
          example.run
        ensure
          ActionController::Base.allow_forgery_protection = orig
        end
      end
    end

    ActionDispatch::Integration::Session.prepend(Module.new do
      mattr_accessor :shred_cookies

      def process(...)
        result = super
        # after a request rails will save the cookie, clear it out after
        # the test so that it doesn't affect other tests - we don't want to
        # send cookies when we are testing other auth methods.
        if shred_cookies
          cookies.to_hash.keys.each do |x|
            Rails.logger.warn('COOKIE JAR DISABLED, deleting cookie after response', cookie: x)

            cookies.delete(x)
          end
        end

        result
      end
    end)

    # deletes cookies sent by set-cookie after each request.
    def disable_cookie_jar
      around do |example|
        integration_session.shred_cookies = true
        example.call
      ensure
        integration_session.shred_cookies = false
      end
    end
  end

  # config.include allows these methods to be used in specs/before/let
  module Example
    def route_exists(path, environment = {})
      result = Rails.application.routes.recognize_path(path, environment)

      result[:controller] != 'errors'
    rescue ActionController::RoutingError
      false
    end

    def supports_destroy_action(path)
      route_exists("#{path}/destroy", { method: :delete })
    end

    def auth_header(token)
      {
        'HTTP_AUTHORIZATION' => token
      }
    end

    def api_request_headers(token, send_body: false, content_type: 'application/json')
      headers = {
        'ACCEPT' => 'application/json',
        'HTTP_AUTHORIZATION' => token
      }
      headers['CONTENT_TYPE'] = content_type if send_body
      headers
    end

    def api_headers(token, accept: 'application/json')
      {
        headers: {
          'ACCEPT' => accept,
          'HTTP_AUTHORIZATION' => token
        },
        as: :json
      }
    end

    def jwt_headers(token, accept: 'application/json')
      {
        headers: {
          'ACCEPT' => accept,
          'HTTP_AUTHORIZATION' => "Bearer #{token}"
        },
        as: :json
      }
    end

    def api_with_body_headers(token, content_type: 'application/json', accept: 'application/json')
      {
        headers: {
          'ACCEPT' => accept,
          'HTTP_AUTHORIZATION' => token,
          'CONTENT_TYPE' => content_type
        },
        as: :json
      }
    end

    def media_request_headers(token, format: 'wav')
      {
        'ACCEPT' => MIME::Types.type_for(format).first.content_type,
        'HTTP_AUTHORIZATION' => token
      }
    end

    def form_multipart_headers(token, accept: 'json')
      {
        headers: {
          'ACCEPT' => MIME::Types.type_for(accept).first.content_type,
          'HTTP_AUTHORIZATION' => token,
          'CONTENT_TYPE' => 'multipart/form-data'
        }
      }
    end

    # Rails/rack basically does not support parsing mixed/related bodies
    # I mostly got it working but the json blob was still a string and it was nested... not worth the effort
    #
    # require 'net/http/post/multipart'
    # # A helper for sending JSON metadata along with one or more files.
    # # Any Pathname object found in the body will be extracted and encoded as a
    # # separate portion of the request.
    # # !!! IMPORTANT !!!
    # # requires use of the `expose_app_as_web_server` helper due to the fact that
    # # Rack::Test does not support multipart requests (other than form-data).
    # def post_multipart_request(url, body, token, accept: 'json')
    #   raise 'body must be an Hash' unless body.is_a? Hash

    #   url = "http://#{Settings.host.name}:#{Settings.host.port}#{url}"

    #   files = {}
    #   body_without_files = body.deep_map { |keys, value|
    #     if value.is_a? Pathname
    #       mime = Mime::Type.lookup_by_extension(value.extname).to_s
    #       form_data_key = keys.first.to_s + keys[1..].map { |x| "[#{x}]" }.join
    #       files[form_data_key] = UploadIO.new(value.open, mime, value.basename)
    #       throw :delete
    #     else
    #       value
    #     end
    #   }

    #   params = { params: body_without_files.to_json, **files }

    #   url = URI.parse(url)
    #   response = Net::HTTP.start(url.host, url.port) { |http|
    #     request = Net::HTTP::Post::Multipart.new(url, params, {
    #       parts: {
    #         data: {
    #           'Content-Type' => 'application/json'
    #         }
    #       }
    #     })
    #     request.add_field('Authorization', token)
    #     request.add_field('Accept', MIME::Types.type_for(accept).first.content_type)
    #     request.add_field('Content-Type', 'multipart/related')
    #     logger.info("multipart request for #{url}", request: request.inspect)

    #     http.request request
    #   }
    #   logger.info("multipart response for #{url}", response:)

    #   response
    # end

    # @param name [Symbol]
    # @param path [Pathname]
    def with_file(path)
      raise 'Must be a Pathname' unless path.is_a?(Pathname)
      raise "File does not exist: #{path}" unless path.exist?

      mime = Mime::Type.lookup_by_extension(path.extname).to_s

      Rack::Test::UploadedFile.new(path, mime)
    end

    def with_range_request_headers(headers, ranges:)
      headers ||= {}
      raise 'ranges must not be empty' if ranges.empty?

      range_spec = ranges.map { |r| "#{r.begin}-#{r.end}" }.join(',')

      headers[RangeRequest::HTTP_HEADER_RANGE] = "bytes=#{range_spec}"

      headers
    end

    def response_body
      # the != false is not redundant here... safe access could result in nil
      # which would evaluate to false and execute wrong half of conditional
      #
      # don't cache this, subsequent requests will not work
      response&.body&.empty? == false ? response.body : nil
    end

    def api_result
      # don't cache this, subsequent requests will not work
      response_body.nil? ? nil : JSON.parse(response_body, symbolize_names: true)
    end

    # Asserts there is a meta/data structure and then extracts data
    def api_data
      expect(api_result).to match(
        {
          meta: an_instance_of(Hash),
          data: an_instance_of(Hash).or(an_instance_of(Array)).and(have_at_least(1).items)
        }
      )

      api_result[:data]
    end

    def expect_json_response
      expect(response.content_type).to eq('application/json; charset=utf-8')
    end

    def expect_binary_response(mime: 'application/octet-stream')
      expect(response.content_type).to eq(mime)
      expect(response.body).not_to be_empty
    end

    def expect_id_matches(expected)
      id = get_id(expected)
      expect(api_result).to include({ data: hash_including({ id: }) })
    end

    def expect_has_ids(*expected)
      expect(api_result[:data]).to be_a(Array)

      expected = expected.flatten

      if expected.empty?
        expect(api_result[:data]).to match([])
      else
        inner = expected
          .map { |x| hash_including({ id: get_id(x) }) }
          .to_a

        expect(api_result).to include(data: a_collection_including(*inner))
      end
    end

    def expect_does_not_have_ids(*expected)
      expect(api_result[:data]).to be_a(Array)

      expected = expected.flatten

      aggregate_failures do
        expected.each do |x|
          expect(api_result[:data]).not_to include(hash_including({ id: get_id(x) }))
        end
      end
    end

    def expect_at_least_one_item
      expect(api_result[:data]).to be_a(Array)
      api_result[:data].should have_at_least(1).items
    end

    def expect_zero_items
      expect_number_of_items(0)
    end

    def expect_number_of_items(n)
      expect(api_result[:data]).to be_a(Array)
      api_result[:data].should have(n).items
    end

    def expect_empty_body
      expect(response.body).to be_empty
    end

    def expect_data_is_hash
      data = api_result[:data]
      expect(data).to be_a(Hash)
      expect(data).not_to be_empty
    end

    def expect_data_is_hash_with_any_id
      expect(api_result).to include({
        data: hash_including({ id: a_kind_of(Integer) })
      })
    end

    def expect_has_projection(projection)
      expect(api_result).to include(meta: hash_including({
        projection:
      }))
    end

    def expect_has_paging(page: 1, items: 25, current: nil, total: nil)
      expected = {
        items:,
        page:
      }
      expected[:current] = current unless current.nil?
      expected[:total] = total unless total.nil?
      expect(api_result).to include(meta: hash_including({
        paging: hash_including(expected)
      }))
    end

    def expect_has_sorting(order_by:, direction: 'asc')
      expect(api_result).to include(meta: hash_including({
        sorting: {
          direction:,
          order_by:
        }
      }))
    end

    def expect_has_filter(filter)
      expect(api_result).to include(meta: hash_including({
        filter:
      }))
    end

    def expect_has_capability(name, can, details = nil)
      { can:, details: } => expected

      expect(api_result).to include(
        meta: hash_including(
          {
            capabilities: hash_including(
              name => expected
            )
          }
        )
      )
    end

    def expect_success
      expect(response).to have_http_status(:success)
    end

    def expect_created
      expect(response).to have_http_status(:created)
    end

    def expect_no_content
      expect(response).to have_http_status(:no_content)
    end

    def expect_error(status, details, info = nil, with_data_matching: nil)
      status = Rack::Utils.status_code(status) if status.is_a?(Symbol)

      raise "Status argument to expect_error is not acceptable: `#{status}`" unless status.is_a?(Integer)

      aggregate_failures 'error response' do
        expect(response).to have_http_status(status)

        expect_json_response

        message = Rack::Utils::HTTP_STATUS_CODES[status]

        error_hash = {}
        error_hash[:details] = details unless details.nil?
        error_hash[:info] = info unless info.nil?
        expect(api_result).to match({
          meta: hash_including({
            status:,
            message:,
            error: hash_including(error_hash)
          }),
          data: with_data_matching.presence
        })
      end
    end

    def expect_gone
      expect_error(:gone, 'The requested item is no longer available')
    end

    def expect_headers_to_include(expected)
      expected = expected.transform_keys(&:downcase)
      expect(response.headers).to match(hash_including(expected))
    end

    def self.included(example_group)
      example_group.after do |example|
        unless example.exception.nil?
          # I don't know of a good way to augment the original error with more
          # information. Raising a new error with more information seems to work OK.

          request_vars = request&.env&.select { |k, _v|
            k.match('^HTTP.*|^CONTENT.*|^REMOTE.*|^REQUEST.*|^AUTHORIZATION.*|^SCRIPT.*|^SERVER.*')
          }
          message = <<~API_RESULT
            Response: #{response&.code}
            Headers: #{response&.headers}
            Body:
            ```
            #{response_body.nil? ? '<empty result>' : response_body.truncate(5_000)}
            ```

            Request: #{request&.url}
            Rack ENV: #{request_vars}
            Body:
            ```
            #{format_request_body}
            ```
          API_RESULT
          raise StandardError, message
        end
      end
    end

    private

    def format_request_body
      return '<empty body>' if request&.body&.rewind.nil? || request.body.nil?

      mime = request&.env&.fetch('CONTENT_TYPE')
      body = request.body.read

      if mime&.start_with?('multipart/form-data') || mime&.start_with?('multipart/mixed') || mime&.start_with?('multipart/related')
        return body.split(/-{10,}.*\r\n"/).map { |x| "#{x.split("\r\n\r\n").first}\n<...snip...>" }.join("\n")
      end

      return body if mime&.start_with?('application/json')

      return "<binary payload of size: #{request.body.size}>" if MIME::Types[mime]&.first&.binary?

      body.truncate(5_000)
    end

    def get_id(anything)
      case anything
      when nil, Integer
        anything
      when ActiveRecord::Base, ->(x) { x.respond_to?(:id) }
        anything.id
      when Hash
        anything[:id] if anything.key?(:id)
        anything['id'] if anything.key?('id')
      else
        anything
      end
    end
  end
end
