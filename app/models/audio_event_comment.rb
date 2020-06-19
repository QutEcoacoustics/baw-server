# frozen_string_literal: true

class AudioEventComment < ApplicationRecord
  extend Enumerize
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  belongs_to :audio_event, inverse_of: :comments
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id', inverse_of: :created_audio_event_comments
  belongs_to :updater, class_name: 'User', foreign_key: 'updater_id', inverse_of: :updated_audio_event_comments, optional: true
  belongs_to :deleter, class_name: 'User', foreign_key: 'deleter_id', inverse_of: :deleted_audio_event_comments, optional: true
  belongs_to :flagger, class_name: 'User', foreign_key: 'flagger_id', inverse_of: :flagged_audio_event_comments

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # enums
  AVAILABLE_FLAGS_SYMBOLS = [:report].freeze
  AVAILABLE_FLAGS = AVAILABLE_FLAGS_SYMBOLS.map(&:to_s)

  AVAILABLE_FLAGS_DISPLAY = [
    { id: :report, name: 'Report' }
  ].freeze

  enumerize :flag, in: AVAILABLE_FLAGS, predicates: true

  # association validations
  validates_associated :audio_event
  validates_associated :creator

  # attribute validations
  validates :comment, presence: true, length: { minimum: 2 }

  # Define filter api settings
  def self.filter_settings
    {
      valid_fields: [:id, :audio_event_id, :comment, :flag, :flag_explain, :flagged_at, :created_at, :creator_id, :updated_at],
      render_fields: [:id, :audio_event_id, :comment, :flag, :creator_id, :updated_at, :created_at],
      text_fields: [:comment, :flag, :flag_explain],
      controller: :audio_event_comments,
      action: :filter,
      defaults: {
        order_by: :updated_at,
        direction: :desc
      },
      valid_associations: [
        {
          join: AudioEvent,
          on: AudioEvent.arel_table[:id].eq(AudioEventComment.arel_table[:audio_event_id]),
          available: true
        }
      ]
    }
  end
end
