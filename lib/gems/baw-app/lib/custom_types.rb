# frozen_string_literal: true

require 'dry-types'

module Baw
  module CustomTypes
    include Dry.Types()

    Pathname = Constructor(::Pathname)
    ExpandedPathname = Constructor(::Pathname) { |value| ::Pathname.new(value).expand_path }

    LogLevel = CustomTypes::String.constrained(included_in: [
      'Logger::DEBUG',
      'Logger::INFO',
      'Logger::WARN',
      'Logger::ERROR',
      'Logger::FATAL',
      'Logger::UNKNOWN'
    ])
  end
end
