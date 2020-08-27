# frozen_string_literal: true

class Dataset < ApplicationRecord
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  #relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_datasets
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_datasets, optional: true
  has_many :dataset_items
  has_many :study

  # We have not enabled soft deletes yet since we do not support deleting datasets
  # This may change in the future

  # association validations
  validates_associated :creator

  # validation
  validates :name, presence: true, length: { minimum: 2 }
  validates :name, unless: -> { id == Dataset.default_dataset_id }, exclusion: { in: ['default'], message: '%{value} is a reserved dataset name' }

  DEFAULT_DATASET_NAME = 'default'

  # lookup the default dataset id
  # This will potentially be hit very often, maybe multiple times per request
  # and therefore is a possible avenue for future optimization if necessary
  def self.default_dataset_id
    # note: this may cause db:create and db:migrate to fail
    default_dataset.id
  end

  # (scope) return the default dataset
  def self.default_dataset
    Dataset.where(name: DEFAULT_DATASET_NAME).first
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
      custom_fields: lambda { |item, _user|
        [item, item.render_markdown_for_api_for(:description)]
      },
      new_spec_fields: lambda { |_user|
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

            }
          ]
        }
      ]
    }
  end

  def self.schema
    {
      type: 'object',
      additionalProperties: false,
      properties: {
        id: { '$ref' => '#/components/schemas/id', readOnly: true },
        name: { type: 'string' },
        **Api::Schema.rendered_markdown(:description),
        **Api::Schema.updater_and_creator_ids_and_ats
      },
      required: [
        :id,
        :name,
        :description,
        :created_at,
        :creator_id,
        :updated_at,
        :updater_id
      ]
    }.freeze
  end
end
