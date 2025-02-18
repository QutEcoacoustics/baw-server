# frozen_string_literal: true

require 'dry/monads'
require 'dry-types'
require 'dry/inflector'

require_relative 'sexagesimal'
require_relative 'byte_format'

extend Dry::Monads[:result, :maybe]
Dry::Types.load_extensions(:monads, :maybe)

module BawApp
  module Types
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
        # These errors happen before the logger is available, don't use rails logger
        # rubocop:disable Rails/Output
        puts "CreatedDirPathname ERROR: Could not create directory #{p}, #{e}"
        # rubocop:enable Rails/Output
        raise e if BawApp.dev_or_test?
      rescue StandardError => e
        # rubocop:disable Rails/Output
        puts "CreatedDirPathname ERROR:  #{e}"
        # rubocop:enable Rails/Output
      end
      p
    }
    PathExists = Constructor(::Pathname) { |value|
      p = ::Pathname.new(value).expand_path
      raise "#{p} does not exist" unless p.exist?

      p
    }

    LogLevel = Types::Coercible::String.enum(
      'Logger::DEBUG', 'Logger::INFO', 'Logger::WARN', 'Logger::ERROR', 'Logger::FATAL', 'Logger::UNKNOWN'
    )

    IPAddr = Constructor(::IPAddr) { |value|
      ::IPAddr.new(value)
    }

    UnixTime = Constructor(::Time) { |value|
      next nil if value.blank?

      ::Time.zone.at(value)
    }

    # Like the standard dry-types Time but assumes local times
    # are in the UTC timezone - not rails default of local timezone.
    # The difference is moot because our app always uses UTC, but since
    # we are dealing with external systems that use local time, we need
    # to be explicit.
    # Implementation is based on the standard dry-types Time:
    # https://github.com/dry-rb/dry-types/blob/2ac0ba485a9c141377151e166861e0e418983495/lib/dry/types/coercions.rb#L64-L78
    UtcTime = Constructor(::Time) { |input|
      if input.respond_to?(:to_str)
        begin
          BawApp.utc_tz.parse(input)
        rescue ArgumentError => e
          ::Dry::Types::CoercionError.handle(e, &block)
        end
      elsif input.is_a?(::Time)
        input
      else
        raise ::Dry::Types::CoercionError, "#{input.inspect} is not a string"
      end
    }

    JsonScalar = Types::JSON::Decimal | Types::String | Types::Nil

    DURATION_REGEX = /\A(?<hours>\d+):(?<minutes>\d{2}):(?<seconds>\d+)\z/
    Sexagesimal = Constructor(Numeric) { |value|
      next nil if value.blank?

      next value if value.is_a?(Numeric)

      ::BawApp::Sexagesimal.parse(value)
    }

    PbsByteFormat = Constructor(Numeric) { |value|
      next nil if value.blank?

      ::BawApp::ByteSize.parse(value)
    }
  end
end
