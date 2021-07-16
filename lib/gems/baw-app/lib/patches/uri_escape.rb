# frozen_string_literal: true

require 'uri'

# URI escape was deprecated for Ruby 3, but paperclip depends on it!
module Baw
  module URI
    module Escape
      PATCH_DEFAULT_PARSER = ::URI::Parser.new
      #
      # == Synopsis
      #
      #   URI.escape(str [, unsafe])
      #
      # == Args
      #
      # +str+::
      #   String to replaces in.
      # +unsafe+::
      #   Regexp that matches all symbols that must be replaced with codes.
      #   By default uses <tt>UNSAFE</tt>.
      #   When this argument is a String, it represents a character set.
      #
      # == Description
      #
      # Escapes the string, replacing all unsafe characters with codes.
      #
      # This method is obsolete and should not be used. Instead, use
      # CGI.escape, URI.encode_www_form or URI.encode_www_form_component
      # depending on your specific use case.
      #
      # == Usage
      #
      #   require 'uri'
      #
      #   enc_uri = URI.escape("http://example.com/?a=\11\15")
      #   # => "http://example.com/?a=%09%0D"
      #
      #   URI.unescape(enc_uri)
      #   # => "http://example.com/?a=\t\r"
      #
      #   URI.escape("@?@!", "!?")
      #   # => "@%3F@%21"
      #
      def escape(*arg)
        __warn_obsolete
        PATCH_DEFAULT_PARSER.escape(*arg)
      end
      alias encode escape
      #
      # == Synopsis
      #
      #   URI.unescape(str)
      #
      # == Args
      #
      # +str+::
      #   String to unescape.
      #
      # == Description
      #
      # This method is obsolete and should not be used. Instead, use
      # CGI.unescape, URI.decode_www_form or URI.decode_www_form_component
      # depending on your specific use case.
      #
      # == Usage
      #
      #   require 'uri'
      #
      #   enc_uri = URI.escape("http://example.com/?a=\11\15")
      #   # => "http://example.com/?a=%09%0D"
      #
      #   URI.unescape(enc_uri)
      #   # => "http://example.com/?a=\t\r"
      #
      def unescape(*arg)
        __warn_obsolete
        PATCH_DEFAULT_PARSER.unescape(*arg)
      end
      alias decode unescape

      def __warn_obsolete
        warn "URI.#{__callee__} is obsolete", uplevel: 2 unless @warned
        @warned = true
      end
    end

    extend Escape
  end
end

URI.extend(Baw::URI::Escape)
