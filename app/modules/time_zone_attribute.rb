# frozen_string_literal: true

require 'tzinfo'
require 'active_support'

# Adds automatic normalization to stored and read timezone
# attributes for active record models
module TimeZoneAttribute
  extend ActiveSupport::Concern

  included do
    validate :tzinfo_tz, :check_tz
  end

  def tzinfo_tz=(value)
    value = nil if value.blank?
    # we're only trying to normalize values here... validation should still occur
    normalized =
      case value
      when String
        search = TimeZoneHelper.to_identifier(value)
        # allow returning invalid values so validation can catch error
        search.nil? ? value : search
      when TZInfo::Timezone, TZInfo::TimezoneProxy
        value.identifier
      else
        value
      end

    # store the actual IANA identifier
    write_attribute(:tzinfo_tz, normalized)
    write_attribute(:rails_tz, TimeZoneHelper.tz_identifier_to_ruby(normalized))
  end

  def tzinfo_tz
    value = read_attribute(:tzinfo_tz)
    # need to return modified value as is so validation works
    return value if tzinfo_tz_changed?

    # otherwise we have a new value from the database
    return value if TimeZoneHelper.identifier?(value) || value.nil?

    # we need to normalize, update value
    value = TimeZoneHelper.to_identifier(value)
    write_attribute(:tzinfo_tz, value)
    write_attribute(:rails_tz, TimeZoneHelper.tz_identifier_to_ruby(value))

    value
  end

  # returns a hash with information about the timezone stored on this model
  def timezone
    TimeZoneHelper.info_hash(tzinfo_tz, rails_tz)
  end

  def check_tz
    tzinfo_identifier = tzinfo_tz
    return if tzinfo_identifier.nil?

    is_invalid = TimeZoneHelper.find_timezone(tzinfo_identifier).blank?

    return unless is_invalid

    suggestions = TimeZoneHelper.tzinfo_friendly_did_you_mean(tzinfo_identifier)[0..2]
    msg1 = "is not a recognized timezone ('#{tzinfo_identifier}'"
    msg2 = suggestions.any? ? " - did you mean '#{suggestions.join("', '")}'?)" : ')'
    errors.add(:tzinfo_tz, msg1 + msg2)
  end
end
