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

  # Define filter api settings
  def self.filter_settings
    return {
        valid_fields: [
            :id, :dataset_item_id, :activity, :creator_id, :created_at
        ],
        render_fields: [
            :id, :dataset_item_id, :activity, :creator_id, :created_at
        ],
        new_spec_fields: lambda { |user|
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
                available: true
            }
        ]
    }
  end

end
