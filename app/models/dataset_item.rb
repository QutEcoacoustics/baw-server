# frozen_string_literal: true

# == Schema Information
#
# Table name: dataset_items
#
#  id                 :integer          not null, primary key
#  end_time_seconds   :decimal(, )      not null
#  order              :decimal(, )
#  start_time_seconds :decimal(, )      not null
#  created_at         :datetime
#  audio_recording_id :integer
#  creator_id         :integer
#  dataset_id         :integer
#
# Indexes
#
#  dataset_items_idx  (start_time_seconds,end_time_seconds)
#
# Foreign Keys
#
#  fk_rails_...  (audio_recording_id => audio_recordings.id)
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (dataset_id => datasets.id)
#
class DatasetItem < ApplicationRecord
  # relationships
  belongs_to :dataset, inverse_of: :dataset_items
  belongs_to :audio_recording, inverse_of: :dataset_items
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_dataset_items
  has_many :progress_events, inverse_of: :dataset_item, dependent: :destroy
  has_many :responses, dependent: :destroy

  # association validations
  validates_associated :dataset
  validates_associated :audio_recording
  validates_associated :creator

  # validation
  validates :start_time_seconds, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :end_time_seconds, presence: true, numericality: { greater_than: :start_time_seconds }
  validates :order, numericality: true, allow_nil: true

  # Define filter api settings
  # @param [Symbol] priority_algorithm The key of the @priority_algorithms to use as the priority virtual field.
  def self.filter_settings(priority_algorithm = nil)
    result = {
      valid_fields: [
        :id, :dataset_id, :audio_recording_id, :start_time_seconds,
        :end_time_seconds, :order, :creator_id, :created_at, :priority
      ],
      render_fields: [
        :id, :dataset_id, :audio_recording_id, :start_time_seconds,
        :end_time_seconds, :order, :creator_id, :created_at
      ],
      new_spec_fields: lambda { |_user|
                         {
                           #dataset_id: nil,
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
          available: true
        },
        {
          join: AudioRecording,
          on: DatasetItem.arel_table[:audio_recording_id].eq(AudioRecording.arel_table[:id]),
          available: true
        }
      ]
    }

    # add the relevant priority algorithm to the field_mapping for "priority" and
    # add "priority" to the valid fields
    if priority_algorithm

      result[:valid_fields] << :priority

      # priority algorithm can either be a key in priority_algorithm
      # or a custom value
      priority_algorithm_value = if @priority_algorithms.key?(priority_algorithm)
                                   @priority_algorithms[priority_algorithm]
                                 else
                                   priority_algorithm
                                 end

      result[:custom_fields2] = {} unless result.key(:custom_fields2)

      result[:custom_fields2][:priority] = {
        query_attributes: [],
        transform: nil,
        arel: priority_algorithm_value,
        type: :string
      }

    end

    result
  end

  # this will contain some named algorithms for sorting the dataset items by priority virtual field
  # Currently only one dummy algorithm for testing
  # Is current_user.id vulnerable to sql injection?
  @priority_algorithms = {
    reverse_order: DatasetItem.arel_table[:order].*(-1)
  }

  # Below is an attempt to sort by number of views in a more Arel way than the SQL in self.next_for_user
  # It didn't quite work but is left here for future reference. In this version, we join to progress events
  # and do a count on progress events grouped by dataset item, however this excludes dataset items with no views.
  # Doing an outer join would mean that dataset items with zero would both have count 1 which is incorrect.
  # scope :num_views, lambda {
  #   joins(:progress_events).select("dataset_items.*, count(DISTINCT progress_events.id) as num_views")
  #      .group('dataset_items.id')
  # }

  # return the value of an SQL order by clause to be used as the
  # priority algorithm value. This SQL orders by number of views, number of own views
  # order, and id
  def self.next_for_user(user_id = nil)
    # sort by least viewed, then least viewed by current user, then id
    order_by_clauses = []

    # first order by the number of views, ascending
    order_by_clauses.push <<~SQL
      (SELECT count(*) FROM progress_events
       WHERE dataset_item_id = dataset_items.id AND progress_events.activity = 'viewed') ASC
    SQL

    # Within dataset items that have the same total views, sort by the number of views by the current user.
    # Anonymous users are permitted to list dataset items, and only items that are associated with permitted
    # projects are shown.
    if user_id
      order_by_clauses.push <<~SQL
        (SELECT count(*) FROM progress_events
         WHERE dataset_item_id = dataset_items.id
         AND progress_events.activity = 'viewed'
         AND progress_events.creator_id = #{user_id}) ASC
      SQL
    end

    # finally, sort by the order field, and then to keep consistent ordering in the case of identical order field
    # sort by id
    order_by_clauses.push 'dataset_items.order ASC'
    order_by_clauses.push 'dataset_items.id ASC'
    order_by_clauses.join(', ')
  end
end
