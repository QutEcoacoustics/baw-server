# allow any origin, with any header, to access the array of methods
# insert as first middleware, after other changes.
# this ensures static files, caching, and auth will include CORS headers
Rails.application.config.middleware.insert_before 0, Rack::Cors, debug: true, logger: (-> { Rails.logger }) do
  allow do

    # 'Access-Control-Allow-Origin' (origins):
    origins Settings.host.cors_origins

    # 'Access-Control-Max-Age' (max_age): "indicates how long the results of a preflight request can be cached"
    # -> not specifying to avoid debugging problems

    # 'Access-Control-Allow-Credentials' (credentials): "Indicates whether or not the response to the request
    # can be exposed when the credentials flag is true.  When used as part of a response to a preflight request,
    # this indicates whether or not the actual request can be made using credentials.  Note that simple GET
    # requests are not preflighted, and so if a request is made for a resource with credentials, if this header
    # is not returned with the resource, the response is ignored by the browser and not returned to web content."
    # -> specifying true to enable authentication on preflight and actual requests.

    # 'Access-Control-Allow-Methods' (methods): "Specifies the method or methods allowed when accessing the
    # resource.  This is used in response to a preflight request."
    # -> including patch, head, options in addition to usual suspects

    # 'Access-Control-Allow-Headers' (headers): "Used in response to a preflight request to indicate which HTTP
    # headers can be used when making the actual request."
    # -> allow any header to be sent by client

    # 'Access-Control-Expose-Headers' (expose): "lets a server whitelist headers that browsers are allowed to access"
    # auto-allowed headers: Cache-Control, Content-Language, Content-Type, Expires, Last-Modified, Pragma
    # http://www.w3.org/TR/cors/#simple-response-header
    # -> we have some custom headers that we want to access, plus content-length

    resource '*', # applies to all resources
              headers: :any,
              methods: [:get, :post, :put, :patch, :head, :delete, :options],
              credentials: true,
              expose: MediaPoll::HEADERS_EXPOSED + %w(X-Archived-At X-Error-Type)
  end
end