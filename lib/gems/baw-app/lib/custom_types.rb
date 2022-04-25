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
      p.mkpath
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
