class Permission < ActiveRecord::Base
  extend Enumerize

  attr_accessible :creator_id, :level, :project_id, :user_id

  belongs_to :project
  belongs_to :user
  belongs_to :creator, class_name: 'User', :foreign_key => 'creator_id'
  belongs_to :updater, class_name: 'User', :foreign_key => 'updater_id'


  AVAILABLE_LEVELS = [:writer, :reader]
  enumerize :level, in: AVAILABLE_LEVELS, predicates: true, multiple: false

  # userstamp
  stampable

  # validate
  validates_uniqueness_of :level, :scope => [:user_id, :project_id, :level]
  validates_presence_of :level, :user, :creator, :project
end
