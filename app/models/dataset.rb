class Dataset < ActiveRecord::Base

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  #relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_datasets
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_datasets
  has_many :dataset_items

  # We have not enabled soft deletes yet since we do not support deleting datasets
  # This may change in the future

  # association validations
  validates :creator, existence: true

  # validation
  validates :name, presence: true, length: {minimum: 2}

end
