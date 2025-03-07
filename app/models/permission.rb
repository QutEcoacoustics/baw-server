# frozen_string_literal: true

# == Schema Information
#
# Table name: permissions
#
#  id              :integer          not null, primary key
#  allow_anonymous :boolean          default(FALSE), not null
#  allow_logged_in :boolean          default(FALSE), not null
#  level           :string           not null
#  created_at      :datetime
#  updated_at      :datetime
#  creator_id      :integer          not null
#  project_id      :integer          not null
#  updater_id      :integer
#  user_id         :integer
#
# Indexes
#
#  index_permissions_on_creator_id           (creator_id)
#  index_permissions_on_project_id           (project_id)
#  index_permissions_on_updater_id           (updater_id)
#  index_permissions_on_user_id              (user_id)
#  permissions_project_allow_anonymous_uidx  (project_id,allow_anonymous) UNIQUE WHERE (allow_anonymous IS TRUE)
#  permissions_project_allow_logged_in_uidx  (project_id,allow_logged_in) UNIQUE WHERE (allow_logged_in IS TRUE)
#  permissions_project_user_uidx             (project_id,user_id) UNIQUE WHERE (user_id IS NOT NULL)
#
# Foreign Keys
#
#  permissions_creator_id_fk  (creator_id => users.id)
#  permissions_project_id_fk  (project_id => projects.id) ON DELETE => cascade
#  permissions_updater_id_fk  (updater_id => users.id)
#  permissions_user_id_fk     (user_id => users.id)
#
class Permission < ApplicationRecord
  extend Enumerize

  belongs_to :project, inverse_of: :permissions
  belongs_to :user, inverse_of: :permissions, optional: true
  belongs_to :creator, class_name: 'User', inverse_of: :created_permissions
  belongs_to :updater, class_name: 'User', inverse_of: :updated_permissions, optional: true

  AVAILABLE_LEVELS_SYMBOLS = Access::Core.levels
  AVAILABLE_LEVELS = AVAILABLE_LEVELS_SYMBOLS.map(&:to_s)
  enumerize :level, in: AVAILABLE_LEVELS, predicates: true

  AVAILABLE_STATUSES_DISPLAY = AVAILABLE_LEVELS_SYMBOLS.map { |l|
    { id: l, name: Access::Core.get_level_name(l) }
  }

  # association validations
  # these validations are now redundant i think
  #validates_associated :project
  #validates_associated :creator
  #validates_associated :user

  # attribute validations
  validates :level, presence: true
  validates :user_id, uniqueness: {
    scope: :project_id,
    conditions: -> { where.not(user_id: nil) },
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
      render_fields: [:id, :project_id, :user_id, :level, :allow_anonymous, :allow_logged_in, :updated_at, :updater_id,
                      :created_at, :creator_id],
      text_fields: [:level],
      new_spec_fields: lambda { |_user|
        {
          project_id: nil,
          user_id: nil,
          level: nil,
          allow_anonymous: false,
          allow_logged_in: false
        }
      },
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
        },
        {
          join: User,
          on: Permission.arel_table[:user_id].eq(User.arel_table[:id]),
          available: true
        }
      ]
    }
  end

  def self.schema
    {
      type: 'object',
      additionalProperties: false,
      properties: {
        id: Api::Schema.id,
        **Api::Schema.updater_and_creator_user_stamps,
        project_id: Api::Schema.id(read_only: false),
        level: Api::Schema.permission_levels,
        user_id: Api::Schema.id(nullable: true, read_only: false),
        allow_logged_in: { type: 'boolean' },
        allow_anonymous: { type: 'boolean' }
      },
      required: [
        :id,
        :project_id,
        :creator_id,
        :created_at,
        :updater_id,
        :updated_at,
        :level,
        :user_id,
        :allow_anonymous,
        :allow_logged_in
      ]
    }.freeze
  end

  private

  # must have only one set
  def exclusive_attributes
    has_user = user.blank? ? 0 : 1
    allows_logged_in = allow_logged_in == true ? 1 : 0
    allows_anon = allow_anonymous == true ? 1 : 0
    exclusive_set = has_user + allows_logged_in + allows_anon

    return unless exclusive_set != 1

    error_msg = 'is not exclusive: '
    error_msg += 'user is set, ' if has_user == 1
    error_msg += 'logged in users is true, ' if allows_logged_in == 1
    error_msg += 'anonymous users is true, ' if allows_anon == 1

    if exclusive_set < 1
      error_msg = 'nothing was set, at least one is required'
      errors.add(:user_id, error_msg)
      errors.add(:allow_logged_in, error_msg)
      errors.add(:allow_anonymous, error_msg)
      return
    end

    errors.add(:user_id, error_msg) if has_user == 1
    errors.add(:allow_logged_in, error_msg) if allow_logged_in
    errors.add(:allow_anonymous, error_msg) if allow_anonymous
  end

  def additional_levels
    if allow_anonymous && level != 'reader'
      errors.add(:level, "must be reader for anonymous user, but was '#{level}'")
      errors.add(:allow_anonymous, "level must be reader, but was '#{level}'")
    end

    return unless allow_logged_in && ['reader', 'writer'].exclude?(level.to_s)

    errors.add(:level, "must be reader or writer for logged in user, but was '#{level}'")
    errors.add(:allow_logged_in, "level must be reader or writer, but was '#{level}'")
  end
end
