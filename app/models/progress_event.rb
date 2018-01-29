class ProgressEvent < ActiveRecord::Base

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_progress_events
  belongs_to :dataset_item, inverse_of: :progress_events

  # association validations
  validates :creator, existence: true
  validates :dataset_item, existence: true

  # field validations

  # Activity types are largely arbitrary. In the future the set of activity types may be changed or the
  # restriction removed altogether
  validates :activity, inclusion: { in: ['viewed', 'played', 'annotated'] }

end
