class Response < ActiveRecord::Base

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  #relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_responses
  belongs_to :question
  belongs_to :study
  belongs_to :dataset_item

  # association validations
  validates :creator, existence: true
  validates :question, existence: true
  validates :study, existence: true
  validates :dataset_item, existence: true


  # Define filter api settings
  def self.filter_settings
    {
        valid_fields: [:id, :data, :created_at, :creator_id, :study_id, :question_id, :dataset_item_id],
        render_fields: [:id, :data, :created_at, :creator_id, :study_id, :question_id, :dataset_item_id],
        new_spec_fields: lambda { |user|
          {
              text: nil,
              data: nil
          }
        },
        controller: :questions,
        action: :filter,
        defaults: {
            order_by: :created_at,
            direction: :desc
        },
        valid_associations: [
            {
                join: Response,
                on: Question.arel_table[:id].eq(Response.arel_table[:question_id]),
                available: true
            },
            {
                join: Arel::Table.new(:questions_studies),
                on: Question.arel_table[:id].eq(Arel::Table.new(:questions_studies)[:question_id]),
                available: false,
                associations: [
                    {
                        join: Study,
                        on: Arel::Table.new(:questions_studies)[:study_id].eq(Study.arel_table[:id]),
                        available: true
                    }
                ]

            }
        ]
    }
  end

end
