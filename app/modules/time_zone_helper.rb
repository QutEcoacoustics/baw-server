# frozen_string_literal: true

require 'tzinfo'
require 'active_support'

# Collection of tiemzone class helper methods
module TimeZoneHelper
  # @used by a view
  # @deprecated Remove when views are removed
  def self.mapping_zone_to_offset
    Hash[
        TZInfo::Timezone.all.map { |tz|
          this_tz = TZInfo::Timezone.get(tz.identifier)
          period = this_tz.current_period
          abbr = period.abbreviation
          offset = period.utc_total_offset # in seconds
          offset_hours = offset / (60 * 60)
          offset_minutes = (offset % 60).to_s.rjust(2, '0')

          if offset_hours.negative?
            offset_hours = (offset_hours * -1).to_s.rjust(2, '0')
            offset_hours = '-' + offset_hours
          else
            offset_hours = '+' + offset_hours.to_s.rjust(2, '0')
          end

          [
            tz.to_s,
            "#{abbr} (#{offset_hours}:#{offset_minutes})"
          ]
        }
    ]
  end

  # Find a Ruby TimeZone which matches the identifier
  # @param [string] identifier Ruby TimeZone identifier or friendly identifier
  def self.find_timezone(identifier)
    TZInfo::Timezone.all.find { |tz| [tz.friendly_identifier, tz.identifier].include? identifier }
  end

  # Retrieve the official identifier of a Ruby TimeZone
  # @param [string] identifier Ruby TimeZone identifier or friendly identifier
  def self.to_identifier(identifier)
    return identifier if identifier?(identifier)

    timezone = find_timezone(identifier)
    timezone.identifier unless timezone.blank?
  end

  # Return true if the given identifier is a valid identifier.
  def self.identifier?(identifier)
    TZInfo::Timezone.get(identifier)
    true
  rescue TZInfo::InvalidTimezoneIdentifier
    false
  end

  # Retrieve the friendly identifier of a Ruby TimeZone
  # @param [string] identifier Ruby TimeZone identifier or friendly identifier
  def self.to_friendly(identifier)
    timezone = find_timezone(identifier)
    timezone.friendly_identifier unless timezone.blank?
  end

  # Get the Ruby TimeZone for the name.
  # @param [string] ruby_tz_name
  # @return [ActiveSupport::TimeZone] TZInfo Timezone
  def self.ruby_tz_class(ruby_tz_name)
    ruby_tz_name.blank? ? nil : ActiveSupport::TimeZone[ruby_tz_name]
  end

  # Get the TZInfo Timezone class for the name.
  # @param [string] tzinfo_tz_identifier
  # @return [TZInfo::Timezone]
  def self.tzinfo_class(tzinfo_tz_identifier)
    tzinfo_tz_identifier.blank? ? nil : TZInfo::Timezone.get(tzinfo_tz_identifier)
  end

  # Get the TZInfo Timezone equivalent to the Ruby TimeZone.
  # @param [string] ruby_tz_name
  # @return [TZInfo::Timezone] TZInfo Timezone
  def self.ruby_to_tzinfo(ruby_tz_name)
    TZInfo::Timezone.get(ActiveSupport::TimeZone::MAPPING[ruby_tz_name])
  end

  # Get the Ruby TimeZone equivalent to the TZInfo Timezone.
  # @param [string] tzinfo_tz_name
  # @return [string] Ruby Timezone
  def self.tz_identifier_to_ruby(tzinfo_tz_name)
    ActiveSupport::TimeZone::MAPPING.invert[tzinfo_tz_name]
  end

  # Get suggestions for a tzinfo friendly name.
  # @param [String] a tzinfo identifier or a friendly string
  # @return [Array<String>]
  # @used
  def self.tzinfo_friendly_did_you_mean(fragment)
    TZInfo::Timezone
      .all
      .filter { |tz|
        tz.friendly_identifier.include?(fragment) || tz.identifier.include?(fragment)
      }
      .map(&:friendly_identifier)
  end

  # Given some seconds, output a [+|-]HH:MM formatted string equivalent
  # @used
  def self.offset_seconds_to_formatted(utc_offset_seconds)
    ActiveSupport::TimeZone.seconds_to_utc_offset(utc_offset_seconds)
  end

  # Format the timezones to a REST friendly response
  def self.info_hash(identifier, rails_identifier)
    tzinfo_tz = TimeZoneHelper.tzinfo_class(identifier)
    rails_tz = TimeZoneHelper.ruby_tz_class(rails_identifier)

    return nil unless tzinfo_tz

    {
      identifier_alt: rails_tz.blank? ? nil : rails_tz.name,
      identifier: tzinfo_tz.identifier,
      friendly_identifier: tzinfo_tz.friendly_identifier,
      utc_offset: rails_tz.blank? ? tzinfo_tz.current_period.utc_offset : rails_tz.utc_offset,
      utc_total_offset: tzinfo_tz.current_period.utc_total_offset
    }
  end
end
