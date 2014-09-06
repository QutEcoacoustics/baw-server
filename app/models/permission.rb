class Permission < ActiveRecord::Base
  extend Enumerize

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  attr_accessible :level, :project_id, :user_id

  belongs_to :project, inverse_of: :permissions
  belongs_to :user
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_permissions
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_permissions

  AVAILABLE_LEVELS_SYMBOLS = [:writer, :reader, :owner]
  AVAILABLE_LEVELS = AVAILABLE_LEVELS_SYMBOLS.map { |item| item.to_s }
  enumerize :level, in: AVAILABLE_LEVELS, predicates: true

  # association validations
  validates :project, existence: true
  validates :user, existence: true
  validates :creator, existence: true

  # attribute validations
  validates_uniqueness_of :level, scope: [:user_id, :project_id, :level]
  validates_presence_of :level, :user, :creator, :project

  # Define filter api settings
  def self.filter_settings
    {
        valid_fields: [:id, :project_id, :user_id, :level, :creator_id, :created_at],
        render_fields: [:id, :project_id, :user_id, :level],
        text_fields: [:level],
        controller: :permissions,
        action: :filter,
        defaults: {
            order_by: :project_id,
            direction: :asc
        }
    }
  end
end