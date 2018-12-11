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

end
