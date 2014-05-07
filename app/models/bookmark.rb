class Bookmark < ActiveRecord::Base
  attr_accessible :audio_recording_id, :name, :description, :offset_seconds

  # relations
  belongs_to :audio_recording, inverse_of: :bookmarks

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_bookmarks
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_bookmarks

  # userstamp
  stampable

  # validation
  validates :offset_seconds, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :audio_recording_id, presence: true

end
