class Tagging < ActiveRecord::Base

  self.table_name = 'audio_events_tags'

  # attr
  attr_accessible :audio_event_id, :tag_id, :tag_attributes

  # relations
  belongs_to :audio_event # no inverse of specified, as it interferes with through: association
  belongs_to :tag # no inverse of specified, as it interferes with through: association
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id

  accepts_nested_attributes_for :audio_event
  accepts_nested_attributes_for :tag

  # add created_at and updated_at stamper
  stampable

  # association validations
  validates :audio_event, existence: true
  validates :tag, existence: true
  validates :creator, existence: true

  # attribute validations
  validates_uniqueness_of :audio_event_id, scope: [:tag_id, :audio_event_id]
  validates_uniqueness_of :tag_id, scope: [:tag_id, :audio_event_id]
end