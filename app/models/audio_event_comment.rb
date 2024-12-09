# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_event_comments
#
#  id             :integer          not null, primary key
#  comment        :text             not null
#  deleted_at     :datetime
#  flag           :string
#  flag_explain   :text
#  flagged_at     :datetime
#  created_at     :datetime
#  updated_at     :datetime
#  audio_event_id :integer          not null
#  creator_id     :integer          not null
#  deleter_id     :integer
#  flagger_id     :integer
#  updater_id     :integer
#
# Indexes
#
#  index_audio_event_comments_on_audio_event_id  (audio_event_id)
#  index_audio_event_comments_on_creator_id      (creator_id)
#  index_audio_event_comments_on_deleter_id      (deleter_id)
#  index_audio_event_comments_on_flagger_id      (flagger_id)
#  index_audio_event_comments_on_updater_id      (updater_id)
#
# Foreign Keys
#
#  audio_event_comments_audio_event_id_fk  (audio_event_id => audio_events.id) ON DELETE => cascade
#  audio_event_comments_creator_id_fk      (creator_id => users.id)
#  audio_event_comments_deleter_id_fk      (deleter_id => users.id)
#  audio_event_comments_flagger_id_fk      (flagger_id => users.id)
#  audio_event_comments_updater_id_fk      (updater_id => users.id)
#
class AudioEventComment < ApplicationRecord
  extend Enumerize

  belongs_to :audio_event, inverse_of: :comments
  belongs_to :creator, class_name: 'User', inverse_of: :created_audio_event_comments
  belongs_to :updater, class_name: 'User', inverse_of: :updated_audio_event_comments,
    optional: true
  belongs_to :deleter, class_name: 'User', inverse_of: :deleted_audio_event_comments,
    optional: true
  belongs_to :flagger, class_name: 'User', inverse_of: :flagged_audio_event_comments,
    optional: true

  # add deleted_at and deleter_id
  acts_as_discardable

  # enums
  AVAILABLE_FLAGS_SYMBOLS = [:report].freeze
  AVAILABLE_FLAGS = AVAILABLE_FLAGS_SYMBOLS.map(&:to_s)

  AVAILABLE_FLAGS_DISPLAY = [
    { id: :report, name: 'Report' }
  ].freeze

  enumerize :flag, in: AVAILABLE_FLAGS, predicates: true

  # association validations
  #validates_associated :audio_event
  #validates_associated :creator

  # attribute validations
  validates :comment, presence: true, length: { minimum: 2 }

  # Define filter api settings
  def self.filter_settings
    {
      valid_fields: [:id, :audio_event_id, :comment, :flag, :flag_explain, :flagged_at, :created_at, :creator_id,
                     :updated_at],
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
