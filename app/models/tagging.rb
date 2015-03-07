class Tagging < ActiveRecord::Base
# ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  self.table_name = 'audio_events_tags'

  # relations
  belongs_to :audio_event, inverse_of: :taggings # inverse_of allows CanCan to make permissions work properly
  belongs_to :tag, inverse_of: :taggings # inverse_of allows CanCan to make permissions work properly
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_taggings
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_taggings

  accepts_nested_attributes_for :audio_event
  accepts_nested_attributes_for :tag

  # association validations
  # the audio_event is added after validation
  #validates :audio_event, existence: true
  validates :tag, existence: true
  validates :creator, existence: true

  # attribute validations
  validates_uniqueness_of :audio_event_id, scope: [:tag_id], message: 'audio_event_id %{value} must be unique within tag_id and audio_event_id'

end