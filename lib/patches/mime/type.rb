# frozen_string_literal: true

require 'English'

# http://blog.choonkeat.com/weblog/2007/02/retrieving-a-se.html
module Mime
  class Type
    class << self
      # Lookup, guesstimate if fail, the file extension
      # for a given mime string. For example:
      #
      # >> Mime::Type.file_extension_of 'text/rss+xml'
      # => "xml"
      def file_extension_of(mime_string)
        set = Mime::LOOKUP[mime_string]
        sym = set.instance_variable_get('@symbol') if set
        return sym.to_s if sym

        $LAST_MATCH_INFO[:last_token] if mime_string =~ /(?<last_token>\w+)$/
      end
    end
  end
end
