class Study < ActiveRecord::Base

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  #relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_studies
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_studies
  has_and_belongs_to_many :questions
  belongs_to :dataset
  has_many :responses

  # association validations
  validates :creator, existence: true
  validates :question, existence: true
  validates :study, existence: true
  validates :dataset_item, existence: true


end
