# frozen_string_literal: true

# Patch that allows for specifying precision for time like objects, on a case by case basis
# https://github.com/rails/rails/blob/e5816783961b20daf6b391ef35ad1345396caf55/activesupport/lib/active_support/core_ext/object/json.rb#L180-L208
module BawWeb
  def self.with_precision(precision)
    return yield if precision.nil?

    unless precision >= 0 && precision <= 9 && precision.is_a?(Integer)
      raise ArgumentError, 'Precision mut be an integer between 0 and 9'
    end

    old = ActiveSupport::JSON::Encoding.time_precision
    ActiveSupport::JSON::Encoding.time_precision = precision
    begin
      yield
    ensure
      ActiveSupport::JSON::Encoding.time_precision = old
    end
  end

  module Time
    def as_json(options = nil) #:nodoc:
      BawWeb.with_precision(options&.fetch(:time_precision, nil)) do
        super(options)
      end
    end
  end

  module DateTime
    def as_json(options = nil) #:nodoc:
      BawWeb.with_precision(options&.fetch(:time_precision, nil)) do
        super(options)
      end
    end
  end
end

Time.prepend(BawWeb::Time)
DateTime.prepend(BawWeb::DateTime)
