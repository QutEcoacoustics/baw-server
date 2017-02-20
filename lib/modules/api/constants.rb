module Api
  module Constants

    # Standard HTTP constants
    HTTP_HEADER_ACCEPT = 'Accept'
    HTTP_HEADER_ACCEPT_ENCODING = 'Accept-Encoding'
    HTTP_HEADER_ACCEPT_LANGUAGE = 'Accept-Language'

    HTTP_HEADER_ACCEPT_RANGES = 'Accept-Ranges'
    HTTP_HEADER_ACCEPT_RANGES_BYTES = 'bytes'
    HTTP_HEADER_ACCEPT_RANGES_BYTES_EQUAL = 'bytes='
    HTTP_HEADER_ACCEPT_RANGES_NONE = 'none'

    HTTP_HEADER_CONTENT_TYPE = 'Content-Type'
    HTTP_HEADER_CONTENT_RANGE = 'Content-Range'
    HTTP_HEADER_CONTENT_LENGTH = 'Content-Length'
    HTTP_HEADER_CONTENT_DISPOSITION = 'Content-Disposition'
    HTTP_HEADER_ENTITY_TAG = 'ETag'
    HTTP_HEADER_LAST_MODIFIED = 'Last-Modified'
    HTTP_HEADER_RANGE = 'Range'
    HTTP_HEADER_IF_RANGE = 'If-Range'
    HTTP_HEADER_IF_MATCH = 'If-Match'
    HTTP_HEADER_IF_NONE_MATCH = 'If-None-Match'
    HTTP_HEADER_IF_MODIFIED_SINCE = 'If-Modified-Since'
    HTTP_HEADER_IF_UNMODIFIED_SINCE = 'If-Unmodified-Since'
    HTTP_HEADER_UNLESS_MODIFIED_SINCE = 'Unless-Modified-Since'

    HTTP_HEADER_COOKIE = 'Cookie'
    HTTP_HEADER_SET_COOKIE = 'Set-Cookie'

    HTTP_HEADER_ACCEPT_JSON = 'application/json'

    HTTP_HEADER_AUTHORIZATION = 'Authorization'
    HTTP_HEADER_HOST = 'Host'
    HTTP_HEADER_CONNECTION = 'Connection'
    HTTP_HEADER_REFERER = 'Referer'

    HTTP_METHOD_GET = 'GET'
    HTTP_METHOD_HEAD = 'HEAD'

    HTTP_CODE_PARTIAL_CONTENT = 206
    HTTP_CODE_PRECONDITION_FAILED = 412
    HTTP_CODE_NOT_MODIFIED = 304
    HTTP_CODE_OK = 200

    # site-wide custom http headers
    HTTP_HEADER_ARCHIVED_AT = 'X-Archived-At'
    HTTP_HEADER_ERROR_TYPE = 'X-Error-Type'
    HTTP_HEADER_CSRF_TOKEN = 'X-XSRF-TOKEN'

    # CORS
    HTTP_HEADER_CORS_ORIGIN = 'Origin'
    HTTP_HEADER_CORS_ACR_METHOD = 'Access-Control-Request-Method'
    HTTP_HEADER_CORS_ACR_HEADERS = 'Access-Control-Request-Headers'

    HTTP_HEADER_CORS_ACA_ORIGIN = 'Access-Control-Allow-Origin'
    HTTP_HEADER_CORS_ACE_HEADERS= 'Access-Control-Expose-Headers'
    HTTP_HEADER_CORS_AC_MAX_AGE = 'Access-Control-Max-Age'
    HTTP_HEADER_CORS_ACA_CREDENTIALS = 'Access-Control-Allow-Credentials'
    HTTP_HEADER_CORS_ACA_METHODS= 'Access-Control-Allow-Methods'
    HTTP_HEADER_CORS_ACA_HEADERS = 'Access-Control-Allow-Headers'

    # media polling
    HTTP_HEADER_RESPONSE_FROM = 'X-Media-Response-From'
    HTTP_HEADER_RESPONSE_START = 'X-Media-Response-Start'

    HTTP_HEADER_RESPONSE_CACHE = 'Cache'
    HTTP_HEADER_RESPONSE_REMOTE = 'Generated Remotely'
    HTTP_HEADER_RESPONSE_LOCAL = 'Generated Locally'

    HTTP_HEADER_ELAPSED_TOTAL = 'X-Media-Elapsed-Seconds-Total'
    HTTP_HEADER_ELAPSED_PROCESSING = 'X-Media-Elapsed-Seconds-Processing'
    HTTP_HEADER_ELAPSED_WAITING = 'X-Media-Elapsed-Seconds-Waiting'

    HTTP_HEADERS_MEDIA_EXPOSED = [
        HTTP_HEADER_CONTENT_LENGTH,
        HTTP_HEADER_RESPONSE_FROM,
        HTTP_HEADER_RESPONSE_START,
        HTTP_HEADER_ELAPSED_TOTAL,
        HTTP_HEADER_ELAPSED_PROCESSING,
        HTTP_HEADER_ELAPSED_WAITING
    ].freeze

    # Range Request
    MULTIPART_BOUNDARY = '<q1w2e3r4t5y6u7i8o9p0>'
    MULTIPART_CONTENT_TYPE = 'multipart/byteranges boundary=' + MULTIPART_BOUNDARY
    DEFAULT_CONTENT_TYPE = 'application/octet-stream'
    MULTIPART_HEADER_LENGTH = 49
    MULTIPART_DASH_LINE_BREAK_LENGTH = 8
    CONVERT_INDEX_TO_LENGTH = 1
    CONVERT_LENGTH_TO_INDEX = -1
    REQUIRED_PARAMETERS = [:start_offset, :end_offset, :recorded_date, :site_id, :site_name, :ext, :file_path, :media_type]

    # User model
    ARCHIVED_USER_NAME = '(archived user)'

  end
end