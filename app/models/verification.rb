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
#  fk_rails_...  (audio_event_id => audio_events.id)
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (tag_id => tags.id)
#  fk_rails_...  (updater_id => users.id)
#
class Verification < ApplicationRecord
  belongs_to :audio_event, inverse_of: :verifications
  belongs_to :tag, inverse_of: :verifications
  belongs_to :creator, class_name: 'User', inverse_of: :created_verifications
  belongs_to :updater, class_name: 'User', inverse_of: :updated_verifications, optional: true

  # A user can only have one verification per audio event and tag
  validates :creator_id, uniqueness: { scope: [:audio_event_id, :tag_id] }

  # Defines the possible values for confirmation
  CONFIRMATION_TRUE = 'true'
  CONFIRMATION_FALSE = 'false'
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
end
