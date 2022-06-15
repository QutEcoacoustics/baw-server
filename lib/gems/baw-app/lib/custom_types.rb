# frozen_string_literal: true

require 'dry-types'
require 'dry/inflector'

module Baw
  module CustomTypes
    include Dry.Types()
    #inflector = Dry::Inflector.new

    Pathname = Constructor(::Pathname)
    ExpandedPathname = Constructor(::Pathname) { |value| ::Pathname.new(value).expand_path }
    CreatedDirPathname = Constructor(::Pathname) { |value|
      p = ::Pathname.new(value).expand_path
      # Super important that this doesn't crash in production
      # We want to be able to serve requests even if our storage is not available
      # but the app will crash while booting
      begin
        p.mkpath
      rescue Errno::EACCES => e
        puts "ERROR: Could not create directory #{p}, #{e}"
        raise e if BawApp.dev_or_test?
      end
      p
    }
    PathExists =

      LogLevel = CustomTypes::Coercible::String.enum(
        'Logger::DEBUG', 'Logger::INFO', 'Logger::WARN', 'Logger::ERROR', 'Logger::FATAL', 'Logger::UNKNOWN'
      )

    IPAddr = Constructor(::IPAddr) { |value|
      ::IPAddr.new(value)
    }
  end
end
