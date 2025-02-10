# frozen_string_literal: true

# A Verification represents a user's confirmation that a tag is correctly
# applied to an audio event.
# @see (#AudioEvent) and (#Tag) for more information on these models.
#
# == Schema Information
#
# Table name: verifications
#
#  id             :bigint           not null, primary key
#  confirmed      :enum             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  audio_event_id :bigint           not null
#  creator_id     :integer          not null
#  tag_id         :bigint           not null
#  updater_id     :integer
#
# Indexes
#
#  idx_on_audio_event_id_tag_id_creator_id_f944f25f20  (audio_event_id,tag_id,creator_id) UNIQUE
#  index_verifications_on_audio_event_id               (audio_event_id)
#  index_verifications_on_tag_id                       (tag_id)
#
# Foreign Keys
#
#  fk_rails_...  (audio_event_id => audio_events.id) ON DELETE => cascade
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (tag_id => tags.id) ON DELETE => cascade
#  fk_rails_...  (updater_id => users.id)
#
class Verification < ApplicationRecord
  belongs_to :audio_event, inverse_of: :verifications
  belongs_to :tag, inverse_of: :verifications
  belongs_to :creator, class_name: 'User', inverse_of: :created_verifications
  belongs_to :updater, class_name: 'User', inverse_of: :updated_verifications, optional: true

  # Defines the possible values for confirmation
  CONFIRMATION_TRUE = 'correct'
  CONFIRMATION_FALSE = 'incorrect'
  CONFIRMATION_UNSURE = 'unsure'
  CONFIRMATION_SKIP = 'skip'

  # @type [Hash{String => String}]
  CONFIRMATION_ENUM = {
    CONFIRMATION_TRUE => CONFIRMATION_TRUE,
    CONFIRMATION_FALSE => CONFIRMATION_FALSE,
    CONFIRMATION_UNSURE => CONFIRMATION_UNSURE,
    CONFIRMATION_SKIP => CONFIRMATION_SKIP
  }.freeze

  # @!method confirmed_true?
  #   @return [Boolean] true if the verification is confirmed as true
  # @!method confirmed_true!
  #   @return [void] sets the verification as confirmed true
  # @!method confirmed_false?
  #   @return [Boolean] true if the verification is confirmed as false
  # @!method confirmed_false!
  #   @return [void] sets the verification as confirmed false
  # @!method confirmed_unsure?
  #   @return [Boolean] true if the verification is marked as unsure
  # @!method confirmed_unsure!
  #   @return [void] sets the verification as unsure
  # @!method confirmed_skip?
  #   @return [Boolean] true if the verification is marked as skip
  # @!method confirmed_skip!
  #   @return [void] sets the verification as skip
  enum :confirmed, CONFIRMATION_ENUM, prefix: :confirmed, validate: true

  def self.filter_settings
    fields = [
      :id, :confirmed, :audio_event_id, :tag_id, :creator_id,
      :updater_id, :created_at, :updated_at
    ]

    {
      valid_fields: fields,
      render_fields: fields,
      text_fields: [],
      new_spec_fields: lambda { |_user|
        {
          confirmed: nil,
          audio_event_id: nil,
          tag_id: nil
        }
      },
      controller: :verifications,
      action: :filter,
      defaults: {
        order_by: :created_at,
        direction: :desc
      },
      valid_associations: [
        {
          join: AudioEvent,
          on: Verification.arel_table[:audio_event_id].eq(AudioEvent.arel_table[:id]),
          available: true,
          associations: [
            {
              join: AudioRecording,
              on: AudioEvent.arel_table[:audio_recording_id].eq(AudioRecording.arel_table[:id]),
              available: true
            }
          ]
        },
        {
          join: Tag,
          on: Verification.arel_table[:tag_id].eq(Tag.arel_table[:id]),
          available: true
        }
      ]
    }
  end

  def self.schema
    {
      type: 'object',
      additionalProperties: false,
      properties: {
        id: Api::Schema.id,
        confirmed: {
          type: 'string',
          enum: CONFIRMATION_ENUM.values
        },
        audio_event_id: Api::Schema.id(read_only: false),
        tag_id: Api::Schema.id(read_only: false),
        **Api::Schema.updater_and_creator_user_stamps
      },
      required: [
        :id,
        :confirmed,
        :audio_event_id,
        :tag_id,
        :creator_id,
        :created_at,
        :updater_id,
        :updated_at
      ]
    }.freeze
  end
end
