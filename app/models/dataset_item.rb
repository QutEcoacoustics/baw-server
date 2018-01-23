class DatasetItem < ActiveRecord::Base

  # relationships
  belongs_to :dataset, inverse_of: :dataset_items
  belongs_to :audio_recording, inverse_of: :dataset_items
  has_many :progress_events, inverse_of: :dataset_item

  # We have not enabled soft deletes yet since we do not support deleting dataset items
  # This may change in the future

  # association validations
  validates :dataset, existence: true
  validates :audio_recording, existence: true

  # validation
  validates :start_time_seconds, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :end_time_seconds, presence: true, numericality: {greater_than: :start_time_seconds}
  validates :order, numericality: true, allow_nil: true

end
