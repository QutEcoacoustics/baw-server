# frozen_string_literal: true

# Extension methods for ActiveRecord models with timestamps
module TimestampHelpers
  extend ActiveSupport::Concern
  include ActiveRecord::Timestamp

  # only define method if the attributes needed exist
  # https://github.com/rails/rails/blob/v6.1.3.2/activerecord/lib/active_record/timestamp.rb

  included do |_base|
    next unless record_timestamps

    # translates to:
    # COALESCE(XXX.updated_at, XXX.created_at)
    def self.arel_updated_or_created
      if respond_to?(:updated_at)
        arel_table[:updated_at].coalesce(arel_table[:created_at])
      else
        arel_table[:created_at]
      end
    end

    scope :most_recent, ->(limit) { order(arel_updated_or_created.desc).limit(limit) }
    scope :created_within, ->(time) { where(arel_table[:created_at] > time) }
    scope :recent_within, ->(time) { where(arel_updated_or_created > time) }
  end
end
