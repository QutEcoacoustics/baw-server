# frozen_string_literal: true

class Permission < ApplicationRecord
  extend Enumerize

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  belongs_to :project, inverse_of: :permissions
  belongs_to :user, inverse_of: :permissions, optional: true
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_permissions
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_permissions, optional: true

  AVAILABLE_LEVELS_SYMBOLS = Access::Core.levels
  AVAILABLE_LEVELS = AVAILABLE_LEVELS_SYMBOLS.map(&:to_s)
  enumerize :level, in: AVAILABLE_LEVELS, predicates: true

  AVAILABLE_STATUSES_DISPLAY = AVAILABLE_LEVELS_SYMBOLS.map { |l|
    { id: l, name: Access::Core.get_level_name(l) }
  }

  # association validations
  validates_associated :project
  validates_associated :creator
  validates_associated :user

  # attribute validations
  validates :level, presence: true
  validates :user_id, uniqueness: {
    scope: :project_id,
    conditions: -> { where('user_id IS NOT NULL') },
    message: 'permission has already been set for project'
  }
  validates :allow_logged_in, uniqueness: {
    scope: :project,
    conditions: -> { where('allow_logged_in IS TRUE') },
    message: 'has already been set for this project'
  }
  validates :allow_anonymous, uniqueness: {
    scope: :project,
    conditions: -> { where('allow_anonymous IS TRUE') },
    message: 'has already been set for this project'
  }
  validates :allow_logged_in, :allow_anonymous, inclusion: { in: [true, false] }

  validate :exclusive_attributes
  validate :additional_levels

  def self.project_list(project_id)
    query = 'SELECT users.id AS user_id, users.user_name,
 (SELECT permissions.level FROM permissions WHERE permissions.project_id = ? AND permissions.user_id = users.id) AS level
 FROM users
 WHERE
   users.user_name <> \'Harvester\'
   AND users.user_name <> \'Admin\'
   AND users.roles_mask = 2
 ORDER BY lower(users.user_name) ASC'

    query = sanitize_sql_array([query, project_id])
    Permission.connection.select_all(query)
  end

  # Define filter api settings
  def self.filter_settings
    {
      valid_fields: [:id, :project_id, :user_id, :level, :allow_anonymous, :allow_logged_in, :creator_id, :created_at],
      render_fields: [:id, :project_id, :user_id, :level, :allow_anonymous, :allow_logged_in],
      text_fields: [:level],
      controller: :permissions,
      action: :filter,
      defaults: {
        order_by: :created_at,
        direction: :desc
      },
      valid_associations: [
        {
          join: Project,
          on: Permission.arel_table[:project_id].eq(Project.arel_table[:id]),
          available: true
        }
      ]
    }
  end

  private

  # must have only one set
  def exclusive_attributes
    has_user = user.blank? ? 0 : 1
    allows_logged_in = allow_logged_in === true ? 1 : 0
    allows_anon = allow_anonymous === true ? 1 : 0
    exclusive_set = has_user + allows_logged_in + allows_anon

    if exclusive_set != 1
      error_msg = 'is not exclusive: '
      error_msg += 'user is set, ' if has_user == 1
      error_msg += 'logged in users is true, ' if allows_logged_in == 1
      error_msg += 'anonymous users is true, ' if allows_anon == 1
      error_msg += 'nothing was set' if exclusive_set < 1

      errors.add(:user_id, error_msg)
      errors.add(:user, error_msg)
      errors.add(:allow_logged_in, error_msg)
      errors.add(:allow_anonymous, error_msg)
    end
  end

  def additional_levels
    if allow_anonymous && level != 'reader'
      errors.add(:level, "must be reader for anonymous user, but was '#{level}'")
      errors.add(:allow_anonymous, "level must be reader, but was '#{level}'")
    end
    if allow_logged_in && !['reader', 'writer'].include?(level.to_s)
      errors.add(:level, "must be reader or writer for logged in user, but was '#{level}'")
      errors.add(:allow_logged_in, "level must be reader or writer, but was '#{level}'")
    end
  end
end
