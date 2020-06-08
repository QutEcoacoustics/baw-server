# frozen_string_literal: true

class ProgressEvent < ApplicationRecord
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_progress_events
  belongs_to :dataset_item, inverse_of: :progress_events

  # association validations
  validates_presence_of :dataset_item
  validates_presence_of :creator

  # field validations

  # Activity types are largely arbitrary. In the future the set of activity types may be changed or the
  # restriction removed altogether
  validates :activity, inclusion: { in: ['viewed', 'played', 'annotated'] }

  # Define filter api settings
  def self.filter_settings
    {
      valid_fields: [
        :id, :dataset_item_id, :activity, :creator_id, :created_at
      ],
      render_fields: [
        :id, :dataset_item_id, :activity, :creator_id, :created_at
      ],
      new_spec_fields: lambda { |_user|
                         {
                           dataset_item_id: nil,
                           activity: nil
                         }
                       },
      controller: :progress_events,
      action: :filter,
      defaults: {
        order_by: :created_at,
        direction: :desc
      },
      valid_associations: [
        {
          join: DatasetItem,
          on: ProgressEvent.arel_table[:dataset_item_id].eq(DatasetItem.arel_table[:id]),
          available: true,
          associations: [
            join: Dataset,
            on: DatasetItem.arel_table[:dataset_id].eq(Dataset.arel_table[:id]),
            available: true
          ]
        }
      ]
    }
  end
end
