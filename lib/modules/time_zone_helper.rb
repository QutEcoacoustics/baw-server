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

  end
end