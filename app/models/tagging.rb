# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_events_tags
#
#  id             :integer          not null, primary key
#  created_at     :datetime
#  updated_at     :datetime
#  audio_event_id :integer          not null
#  creator_id     :integer          not null
#  tag_id         :integer          not null
#  updater_id     :integer
#
# Indexes
#
#  index_audio_events_tags_on_audio_event_id_and_tag_id  (audio_event_id,tag_id) UNIQUE
#  index_audio_events_tags_on_creator_id                 (creator_id)
#  index_audio_events_tags_on_updater_id                 (updater_id)
#
# Foreign Keys
#
#  audio_events_tags_audio_event_id_fk  (audio_event_id => audio_events.id)
#  audio_events_tags_creator_id_fk      (creator_id => users.id)
#  audio_events_tags_tag_id_fk          (tag_id => tags.id)
#  audio_events_tags_updater_id_fk      (updater_id => users.id)
#
class Tagging < ApplicationRecord
  self.table_name = 'audio_events_tags'

  # relations
  belongs_to :audio_event, inverse_of: :taggings # inverse_of allows CanCan to make permissions work properly
  belongs_to :tag, inverse_of: :taggings # inverse_of allows CanCan to make permissions work properly
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_taggings
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_taggings, optional: true

  accepts_nested_attributes_for :audio_event
  accepts_nested_attributes_for :tag

  # association validations
  # the audio_event is added after validation
  #validates_associated :audio_event
  #  validates_associated :tag
  #validates_associated :creator

  # attribute validations
  validates_uniqueness_of :audio_event_id, scope: [:tag_id],
    message: 'audio_event_id %<value>s must be unique within tag_id and audio_event_id'

  # postgres-specific
  scope :count_unique, -> { Tagging.select(:tag_id).distinct.count }

  # Define filter api settings
  def self.filter_settings
    {
      valid_fields: [:id, :audio_event_id, :tag_id, :created_at, :updated_at, :creator_id, :updater_id],
      render_fields: [:id, :audio_event_id, :tag_id, :created_at],
      controller: :taggings,
      action: :filter,
      defaults: {
        order_by: :id,
        direction: :asc
      },
      valid_associations: [
        {
          join: AudioEvent,
          on: Tagging.arel_table[:audio_event_id].eq(AudioEvent.arel_table[:id]),
          available: true
        },
        {
          join: Tag,
          on: Tagging.arel_table[:tag_id].eq(Tag.arel_table[:id]),
          available: true
        }
      ]
    }
  end
end
