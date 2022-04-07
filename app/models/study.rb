# frozen_string_literal: true

# == Schema Information
#
# Table name: studies
#
#  id         :integer          not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  creator_id :integer
#  dataset_id :integer
#  updater_id :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (dataset_id => datasets.id)
#  fk_rails_...  (updater_id => users.id)
#
class Study < ApplicationRecord
  #relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_studies
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_studies, optional: true
  has_and_belongs_to_many :questions, -> { distinct }
  belongs_to :dataset
  has_many :responses, dependent: :destroy

  # association validations
  validates :creator, presence: true
  validates :dataset, presence: true

  # Define filter api settings
  def self.filter_settings
    {
      valid_fields: [:id, :dataset_id, :name, :created_at, :creator_id, :updated_at, :updater_id],
      render_fields: [:id, :dataset_id, :name, :created_at, :creator_id, :updated_at, :updater_id],
      new_spec_fields: lambda { |_user|
                         {
                           name: nil
                         }
                       },
      controller: :studies,
      action: :filter,
      defaults: {
        order_by: :created_at,
        direction: :desc
      },
      valid_associations: [
        {
          join: Dataset,
          on: Study.arel_table[:dataset_id].eq(Dataset.arel_table[:id]),
          available: true
        },
        {
          join: Arel::Table.new(:questions_studies),
          on: Study.arel_table[:id].eq(Arel::Table.new(:questions_studies)[:study_id]),
          available: false,
          associations: [
            {
              join: Question,
              on: Arel::Table.new(:questions_studies)[:question_id].eq(Question.arel_table[:id]),
              available: true
            }
          ]

        }
      ]
    }
  end
end
