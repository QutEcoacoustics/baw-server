class Tagging < ActiveRecord::Base

  self.table_name = 'audio_events_tags'

  # attr
  attr_accessible :audio_event_id, :tag_id, :tag_attributes

  # relations
  belongs_to :audio_event # no inverse of specified, as it interferes with through: association
  belongs_to :tag # no inverse of specified, as it interferes with through: association
  belongs_to :creator, :class_name => 'User', :foreign_key => :creator_id

  accepts_nested_attributes_for :audio_event
  accepts_nested_attributes_for :tag

  #userstamp
  stampable

  ##validations
  validates_presence_of  :audio_event
  validates_presence_of  :tag
  #
  #validates_uniqueness_of :audio_event_id, :scope => :tag_id
end