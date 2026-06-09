module Baw
  module DataPackage
    module Profile
      # Our output packages use a GitHub URI for the camtrap-dp-acoustic profile. We want to
      # resolve this locally rather than fetch it over HTTP, but the gem only supports loading
      # profiles from HTTP URIs or its internal registry and local file paths aren't handled.
      # This patch adds a local file check to Profile#get_profile_from_registry before
      # falling back to the registry lookup.
      def get_profile_from_registry(descriptor)
        return load_json(descriptor) if File.exist?(descriptor)

        # Original behaviour below
        @registry = ::DataPackage::Registry.new
        profile_metadata = @registry.profiles.fetch(descriptor)
        profile_path = if profile_metadata.fetch('schema_path', nil)
                         join_paths(base_path(@registry.path), profile_metadata['schema_path'])
                       else
                         profile_metadata['schema']
                       end
        load_json(profile_path)
      rescue KeyError
        raise DataPackage::ProfileException.new "Couldn't find profile with id `#{descriptor}` in registry"
      end
    end
  end

  # Patches the issue https://github.com/frictionlessdata/tableschema-rb/issues/40
  # Don't want to fail validation if a value is nil and not required.
  module TableSchema
    module Field
      def cast_value(value, constraints: true)
        cast_value = cast_type(value)
        return cast_value if constraints == false
        return cast_value if cast_value.nil? && @required == false

        ::TableSchema::Constraints.new(self, cast_value).validate!
        cast_value
      end
    end

    module Types
      module Base
        private

        # 1) Patches the issue https://github.com/frictionlessdata/tableschema-rb/issues/38
        # TableSchema expects date/datetime format strings to have a `fmt:` prefix (from an outdated
        # Data Package Standard), but our schemas omit it. Without the prefix, TableSchema's dynamic
        # dispatch would try to call `cast_%Y-%m...`, raising a NoMethodError. So we also check for
        # a bare strptime string and handle it the same way.
        # 2) Also, ruby doesn't have %f for fractional seconds, but the schema uses it.
        # So replace %f with %N to correctly parse fractional seconds with microsecond precision.
        # The cast fmt method uses DateTime.strptime, which doesn't support a digit count, so any number of fractional seconds will be parsed.
        def set_format
          field_format = @field[:format] || ''

          if field_format.start_with?('fmt:')
            @format, @format_string = *field_format.split(':', 2)
          elsif field_format.include?('%')
            @format = 'fmt'
            @format_string = field_format.gsub('%f', '%N')
          else
            @format = field_format.presence || ::TableSchema::DEFAULTS[:format]
          end
        end
      end
    end

    # `check_pattern` calls `@value.to_json` before passing it to the regex matcher. For string values, `to_json` wraps
    # the output in double quotes, so `audio/mpeg` becomes `"audio/mpeg"`. A pattern anchored with `^` then fails
    # because the leading `"` sits before the expected match position.
    # Instead, if the value is a string, pass it directly to the matcher, otherwise call `to_json` as before to preserve
    # the original behaviour for non-string values.
    module Constraints
      module Pattern
        def check_pattern
          constraint = ->(value) { value.match(/#{@constraints[:pattern]}/) }
          valid = if @field.type == 'yearmonth'
                    constraint.call(Date.new(@value[:year], @value[:month]).strftime('%Y-%m'))
                  else
                    constraint.call(@value.is_a?(String) ? @value : @value.to_json)
                  end

          unless valid
            raise ::TableSchema::ConstraintError.new("The value for the field `#{@field[:name]}` must match the pattern")
          end

          true
        end
      end
    end
  end
end

# For some reason, the patch causes a 'stray' nested constant to appear DataPackage::Resource::DataPackage
# This breaks constant resolution when Resource#initialize evaluates `@profile = DataPackage::Profile.new()`:
# <NameError: uninitialized constant DataPackage::Resource::DataPackage::Profile>
# The fix is to remove the nested constant
if defined?(DataPackage::Resource) && DataPackage::Resource.const_defined?(:DataPackage, false)
  DataPackage::Resource.send(:remove_const, :DataPackage)
end

DataPackage::Profile.prepend(Baw::DataPackage::Profile) if defined?(DataPackage::Profile)
TableSchema::Field.prepend(Baw::TableSchema::Field) if defined?(TableSchema::Field)
TableSchema::Types::Base.prepend(Baw::TableSchema::Types::Base) if defined?(TableSchema::Types::Base)
if defined?(TableSchema::Constraints::Pattern)
  TableSchema::Constraints::Pattern.prepend(Baw::TableSchema::Constraints::Pattern)
end

# Types = Dry.Types
# class Abc < BawWorkers::Export::CamtrapDp::Datapackage::DpStruct
#   attribute :name, Types::String
#   attribute :date, ::BawApp::Types::UtcTime
# end

# abc = Abc.new(name: 'test', date: '2024-01-01T12:00:00Z')
# abc.to_h

# watched = ['ActiveSupport::TimeWithZone', 'Time', 'DateTime', 'Date', 'JSON']

# trace = TracePoint.new(:call, :c_call) do |tp|
#   puts "#{tp.defined_class}##{tp.method_id}" if watched.any? { |c| tp.defined_class.to_s.include?(c) }
# end

# trace.enable
# JSON.pretty_generate(abc.to_h)
# trace.disable
