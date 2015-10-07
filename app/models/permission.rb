class Permission < ActiveRecord::Base
  extend Enumerize

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  belongs_to :project, inverse_of: :permissions
  belongs_to :user, inverse_of: :permissions
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_permissions
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_permissions


  AVAILABLE_LEVELS_SYMBOLS = Access::Core.levels_allow
  AVAILABLE_LEVELS = AVAILABLE_LEVELS_SYMBOLS.map { |item| item.to_s }
  enumerize :level, in: AVAILABLE_LEVELS, predicates: true

  AVAILABLE_STATUSES_DISPLAY = AVAILABLE_LEVELS_SYMBOLS.map do |l|
    {id: l, name: Access::Core.get_level_name(l)}
  end

  # association validations
  validates :project, existence: true
  validates :creator, existence: true

  # attribute validations
  validates :level, presence: true
  validates :user_id,
            uniqueness:
                {scope: :project_id,
                 conditions: -> { where('user_id IS NOT NULL') },
                 message: 'permission has already been set for project'}
  validates :allow_logged_in, uniqueness:
                                {scope: :project,
                                 conditions: -> { where(allow_logged_in: true) },
                                 message: 'has already been set for this project'}
  validates :allow_anonymous, uniqueness:
                                {scope: :project,
                                 conditions: -> { where(allow_anonymous: true) },
                                 message: 'has already been set for this project'}
  validates :allow_logged_in, :allow_anonymous, inclusion: {in: [true, false]}

  validate :exclusive_attributes
  validate :additional_levels

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
    has_user = self.user.blank? ? 0 : 1
    allows_logged_in = self.allow_logged_in ? 1 : 0
    allows_anon = self.allow_anonymous ? 1 : 0
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
    if self.allow_anonymous && self.level != 'reader'
      errors.add(:level, "must be reader for anonymous user, but was '#{self.level}'")
      errors.add(:allow_anonymous, "level must be reader, but was '#{self.level}'")
    end
    if self.allow_logged_in && !%w(reader writer).include?(self.level.to_s)
      errors.add(:level, "must be reader or writer for logged in user, but was '#{self.level}'")
      errors.add(:allow_logged_in, "level must be reader or writer, but was '#{self.level}'")
    end
  end

end