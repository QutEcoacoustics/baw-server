class ProgressEvent < ActiveRecord::Base

  # relationships
  belongs_to :user, inverse_of: :progress_events
  belongs_to :dataset_item, inverse_of: :progress_events

  # association validations
  validates :user, existence: true
  validates :dataset_item, existence: true

  # field validations

  # Activity types are largely arbitrary. In the future the set of activity types may be changed or the
  # restriction removed altogether
  validates :activity, inclusion: { in: ['viewed', 'played', 'annotated'] }


end
