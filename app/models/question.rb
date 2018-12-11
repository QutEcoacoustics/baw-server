class Question < ActiveRecord::Base

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  #relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_questions
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_questions
  has_and_belongs_to_many :study
  has_many :responses

  # association validations
  validates :creator, existence: true

end
