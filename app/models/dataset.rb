class Dataset < ActiveRecord::Base

  #relationships
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id', inverse_of: :created_datasets
  has_many :dataset_items

  # add deleted_at and deleter_id
  # TODO: ask anthony

  # association validations
  validates :creator, existence: true


  # validation
  validates :name, presence: true, length: {minimum: 2}



end
