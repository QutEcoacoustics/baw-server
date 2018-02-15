class DatasetItem < ActiveRecord::Base

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # relationships
  belongs_to :dataset, inverse_of: :dataset_items
  belongs_to :audio_recording, inverse_of: :dataset_items
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_dataset_items
  has_many :progress_events, inverse_of: :dataset_item

  # We have not enabled soft deletes yet since we do not support deleting dataset items
  # This may change in the future

  # association validations
  validates :dataset, existence: true
  validates :audio_recording, existence: true
  validates :creator, existence: true

  # validation
  validates :start_time_seconds, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :end_time_seconds, presence: true, numericality: {greater_than: :start_time_seconds}
  validates :order, numericality: true, allow_nil: true

  # Define filter api settings
  def self.filter_settings
    {
        valid_fields: [
            :id, :dataset_id, :audio_recording_id, :start_time_seconds, :end_time_seconds, :order, :creator_id, :created_at
        ],
        render_fields: [
            :id, :dataset_id, :audio_recording_id, :start_time_seconds, :end_time_seconds, :order, :creator_id, :created_at
        ],
        new_spec_fields: lambda { |user|
          {
              dataset_id: nil,
              audio_recording_id: nil,
              start_time_seconds: nil,
              end_time_seconds: nil,
              order: nil
          }
        },
        controller: :dataset_items,
        action: :filter,
        defaults: {
            order_by: :order,
            direction: :asc
        },
        valid_associations: [
            {
                join: Dataset,
                on: DatasetItem.arel_table[:dataset_id].eq(Dataset.arel_table[:id]),
                available: true
            },
            {
                join: ProgressEvent,
                on: DatasetItem.arel_table[:id].eq(ProgressEvent.arel_table[:dataset_item_id]),
                available: true,
            },
            {
                join: AudioRecording,
                on: DatasetItem.arel_table[:audio_recording_id].eq(AudioRecording.arel_table[:id]),
                available: true,
            }
        ]
    }
  end

end
