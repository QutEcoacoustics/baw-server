class Question < ActiveRecord::Base

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  #relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_questions
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_questions
  has_and_belongs_to_many :studies, -> { uniq }
  has_many :responses, dependent: :destroy

  # association validations
  validates :creator, existence: true

  # todo: validate that question is associated with at least one study

  # Define filter api settings
  def self.filter_settings
    {
        valid_fields: [:id, :text, :data, :created_at, :creator_id, :updated_at, :updater_id, :study_ids],
        render_fields: [:id, :text, :data, :created_at, :creator_id, :updated_at, :updater_id],
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

  # limit the results to questions associated with a study of the given id
  scope :belonging_to_study, lambda { |study_id|
    joins(:questions_studies).where('questions_studies.study_id = ?', study_id)
  }



end