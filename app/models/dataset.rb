# frozen_string_literal: true

# == Schema Information
#
# Table name: datasets
#
#  id          :integer          not null, primary key
#  description :text
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  creator_id  :integer
#  updater_id  :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (updater_id => users.id)
#
class Dataset < ApplicationRecord
  DEFAULT_DATASET_NAME = 'default'

  # relationships
  belongs_to :creator, class_name: 'User', inverse_of: :created_datasets
  belongs_to :updater, class_name: 'User', inverse_of: :updated_datasets, optional: true
  has_many :dataset_items, dependent: :destroy
  has_many :study, dependent: :destroy

  # We have not enabled soft deletes yet since we do not support deleting datasets
  # This may change in the future

  # association validations
  #validates_associated :creator

  # validation
  validates :name, presence: true, length: { minimum: 2 }
  validates :name, unless: lambda {
                             id == Dataset.default_dataset_id
                           }, exclusion: { in: ['default'], message: '%<value>s is a reserved dataset name' }

  # lookup the default dataset id
  # This will potentially be hit very often, maybe multiple times per request
  # and therefore is a possible avenue for future optimization if necessary
  def self.default_dataset_id
    find_or_create_default.id
  end

  # (scope) return the default dataset
  def self.default_dataset
    find_or_create_default
  end

  def self.find_or_create_default(owner = nil)
    # we cache the default dataset to avoid hitting the database multiple times
    # however, the caching can mess up tests, which recreate and destroy the item frequently
    # and makes this cache invalid. So we disable it in test mode
    return @default_dataset if @default_dataset && !BawApp.test?

    default = Dataset.find_by(name: DEFAULT_DATASET_NAME)

    return default if default

    default = Dataset.new(
      name: DEFAULT_DATASET_NAME,
      description: 'The default dataset',
      creator_id: owner || User.admin_user.id
    )

    default.save!(validate: false)

    @default_dataset = default

    default
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
        **Api::Schema.updater_and_creator_user_stamps
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
