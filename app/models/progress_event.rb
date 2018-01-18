class ProgressEvent < ActiveRecord::Base

  # relationships
  belongs_to :user, inverse_of: :progress_events
  belongs_to :dataset_item, inverse_of: :progress_events

  # add deleted_at and deleter_id
  # TODO: ask anthony

  # association validations
  validates :user, existence: true
  validates :dataset_item, existence: true

  # field validations
  validates :activity, inclusion: { in: ['viewed', 'played', 'annotated'] }



end
