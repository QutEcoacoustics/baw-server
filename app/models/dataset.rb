class Dataset < ActiveRecord::Base

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  #relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_datasets
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_datasets
  has_many :dataset_items

  # We have not enabled soft deletes yet since we do not support deleting datasets
  # This may change in the future

  # association validations
  validates :creator, existence: true

  # validation
  # validates :name, presence: true, length: {minimum: 2}
  validates :name, presence: true, length: {minimum: 2}, exclusion: { in: ['default'], message: "%{value} is a reserved dataset name" }


  # lookup the default dataset id
  # This will potentially be hit very often, maybe multiple times per request
  # and therefore is a possible avenue for future optimization if necessary
  def self.default_dataset_id
    Dataset.where(name: 'default').first.id
  end

  # Define filter api settings
  def self.filter_settings
    {
        valid_fields: [
            :id, :name, :description, :created_at, :creator_id, :updated_at, :updater_id
        ],
        render_fields: [
            :id, :name, :description, :created_at, :creator_id, :updated_at, :updater_id
        ],
        new_spec_fields: lambda { |user|
          {
              name: nil,
              description: nil
          }
        },
        controller: :datasets,
        action: :filter,
        defaults: {
            order_by: :name,
            direction: :asc
        },
        valid_associations: [
            {
                join: DatasetItem,
                on: Dataset.arel_table[:id].eq(DatasetItem.arel_table[:dataset_id]),
                available: true,
                associations: [
                    {
                        join: ProgressEvent,
                        on: DatasetItem.arel_table[:id].eq(ProgressEvent.arel_table[:dataset_item_id]),
                        available: true,
                        associations: []

                    },
                    {
                        join: AudioRecording,
                        on: DatasetItem.arel_table[:audio_recording_id].eq(AudioRecording.arel_table[:id]),
                        available: true,
                        associations: []

                    },
                ]
            }
        ]
    }
  end



end
