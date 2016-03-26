require 'tzinfo'
require 'active_support'

class TimeZoneHelper
  class << self
    def mapping_zone_to_offset
      Hash[
          TZInfo::Timezone.all.map do |tz|
            this_tz = TZInfo::Timezone.get(tz.identifier)
            period = this_tz.current_period
            abbr = period.abbreviation
            offset = period.utc_total_offset # in seconds
            offset_hours = offset / (60 * 60)
            offset_minutes = (offset % 60).to_s.rjust(2, '0')

            if offset_hours < 0
              offset_hours = (offset_hours * -1).to_s.rjust(2, '0')
              offset_hours = '-' + offset_hours
            else
              offset_hours = '+'+ offset_hours.to_s.rjust(2, '0')
            end

            [
                tz.to_s,
                "#{abbr} (#{offset_hours}:#{offset_minutes})"
            ]
          end
      ]
    end

    def to_identifier(friendly_name)
      found = TZInfo::Timezone.all.select { |tz| friendly_name == tz.friendly_identifier }
      if found.size == 1
        found[0].identifier
      else
        nil
      end
    end

    def to_friendly(identifier)
      found = TZInfo::Timezone.all.select { |tz| identifier == tz.identifier }
      if found.size == 1
        found[0].friendly_identifier
      else
        nil
      end
    end

    # Get the Ruby TimeZone for the name.
    # @param [string] ruby_tz_name
    # @return [ActiveSupport::TimeZone] TZInfo Timezone
    def ruby_tz_class(ruby_tz_name)
      ruby_tz_name.blank? ? nil : ActiveSupport::TimeZone[ruby_tz_name]
    end

    # Get the TZInfo Timezone class for the name.
    # @param [string] tzinfo_tz_identifier
    # @return [TZInfo::Timezone]
    def tzinfo_class(tzinfo_tz_identifier)
      tzinfo_tz_identifier.blank? ? nil : TZInfo::Timezone.get(tzinfo_tz_identifier)
    end

    # Get the TZInfo Timezone equivalent to the Ruby TimeZone.
    # @param [string] ruby_tz_name
    # @return [TZInfo::Timezone] TZInfo Timezone
    def ruby_to_tzinfo(ruby_tz_name)
      TZInfo::Timezone.get(ActiveSupport::TimeZone::MAPPING[ruby_tz_name])
    end

    # Get the Ruby TimeZone equivalent to the TZInfo Timezone.
    # @param [string] tzinfo_tz_name
    # @return [string] Ruby Timezone
    def tzinfo_to_ruby(tzinfo_tz_name)
      ActiveSupport::TimeZone::MAPPING.invert[tzinfo_tz_name]
    end

    # Check if a tzinfo friendly id is valid.
    # @param [Site, User] model
    # @return [Boolean]
    def validate_tzinfo_tz(model)
      tzinfo_friendly = model.tzinfo_tz
      is_invalid = to_identifier(tzinfo_friendly).blank?
      if !model.tzinfo_tz.blank? && is_invalid
        suggestions = tzinfo_friendly_did_you_mean(tzinfo_friendly)[0..2]
        msg1 = "is not a recognised timezone ('#{tzinfo_friendly}'"
        msg2 = suggestions.any? ? " - did you mean '#{suggestions.join("', '")}'?)" : ')'
        model.errors[:tzinfo_tz] <<  msg1 + msg2
      end
    end

    # Get suggestions for a tzinfo friendly name.
    # @param [String] tzinfo_friendly
    # @return [Array<String>]
    def tzinfo_friendly_did_you_mean(tzinfo_friendly)
      matches = []
      TZInfo::Timezone.all.each do |tz|
        matches << tz.friendly_identifier if tz.friendly_identifier.include?(tzinfo_friendly)
      end
      matches
    end

    # Set rails time zone from tzinfo time zone.
    # @param [Site, User] model
    # @return [void]
    def set_rails_tz(model)
      tz_info_id = TimeZoneHelper.to_identifier(model.tzinfo_tz)
      rails_tz_string = TimeZoneHelper.tzinfo_to_ruby(tz_info_id)
      if model.tzinfo_tz.blank? && tz_info_id.nil?
        model.rails_tz = nil
      elsif !rails_tz_string.blank?
        model.rails_tz = rails_tz_string
      end
    end

    def offset_seconds_to_formatted(utc_offset_seconds)
      is_neg = utc_offset_seconds < 0
      sec = utc_offset_seconds.abs
      hours = (sec / (60 * 60)).floor.to_s.rjust(2, '0')
      minutes = ((sec % (60 * 60)) / 60).floor.to_s.rjust(2, '0')
      "#{is_neg ? '-' : '+'}#{hours}:#{minutes}"
    end

    def info_hash(model)
      # the model stores the tzinfo friendly_identifier
      tzinfo_tz_string = TimeZoneHelper.to_identifier(model.tzinfo_tz)
      tzinfo_tz = tzinfo_class(tzinfo_tz_string)

      rails_tz_string = model.rails_tz
      rails_tz = ruby_tz_class(rails_tz_string)

      tzinfo_tz = ruby_to_tzinfo(rails_tz_string) if !rails_tz.blank? && tzinfo_tz.blank?
      rails_tz = tzinfo_to_ruby(tzinfo_tz_string) if rails_tz.blank? && !tzinfo_tz.blank?

      if tzinfo_tz
        {
            identifier_alt: rails_tz.blank? ? nil : rails_tz.name,
            identifier: tzinfo_tz.identifier,
            friendly_identifier: tzinfo_tz.friendly_identifier,
            utc_offset: rails_tz.blank? ? tzinfo_tz.current_period.utc_offset : rails_tz.utc_offset,
            utc_total_offset: tzinfo_tz.current_period.utc_total_offset
        }
      else
        nil
      end
    end

  end
end