# frozen_string_literal: true

class Response < ApplicationRecord
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_responses
  belongs_to :question
  belongs_to :study
  belongs_to :dataset_item

  # association validations
  validates :creator, presence: true
  validates :question, presence: true
  validates :study, presence: true
  validates :dataset_item, presence: true
  validates :data, presence: true

  # Response is associated with study directly and also via question
  # validate that the associated study and question are associated with each other

  validate :consistent_associations

  # Define filter api settings
  def self.filter_settings
    {
      valid_fields: [:id, :data, :created_at, :creator_id, :study_id, :question_id, :dataset_item_id],
      render_fields: [:id, :data, :created_at, :creator_id, :study_id, :question_id, :dataset_item_id],
      new_spec_fields: lambda { |_user|
                         {
                           data: nil
                         }
                       },
      controller: :responses,
      action: :filter,
      defaults: {
        order_by: :created_at,
        direction: :desc
      },
      valid_associations: [
        {
          join: Question,
          on: Question.arel_table[:id].eq(Response.arel_table[:question_id]),
          available: true
        },
        {
          join: Study,
          on: Study.arel_table[:id].eq(Response.arel_table[:study_id]),
          available: true
        },
        {
          join: DatasetItem,
          on: DatasetItem.arel_table[:id].eq(Response.arel_table[:dataset_item_id]),
          available: true
        }
      ]
    }
  end

  private

  def consistent_associations
    if !study.nil? && !question.nil?
      unless study.question_ids.include?(question.id)
        errors.add(:question_id, 'parent question is not associated with parent study')
      end
    end
    if !study.nil? && !dataset_item.nil?
      if study.dataset_id != dataset_item.dataset_id
        errors.add(:dataset_item_id, 'dataset item and study must belong to the same dataset')
      end
    end
  end
end
