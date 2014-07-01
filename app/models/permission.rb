class Permission < ActiveRecord::Base
  extend Enumerize

  attr_accessible :creator_id, :level, :project_id, :user_id

  belongs_to :project, inverse_of: :permissions
  belongs_to :user
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_permissions
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_permissions


  AVAILABLE_LEVELS = [:writer, :reader]
  enumerize :level, in: AVAILABLE_LEVELS, predicates: true

  # add created_at and updated_at stamper
  stampable

  # association validations
  validates :project, existence: true
  validates :user, existence: true
  #validates :creator, existence: true

  # attribute validations
  validates_uniqueness_of :level, scope: [:user_id, :project_id, :level]
  validates_presence_of :level, :user, :creator, :project
end
