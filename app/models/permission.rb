class Permission < ActiveRecord::Base
  extend Enumerize

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  belongs_to :project, inverse_of: :permissions
  belongs_to :user
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_permissions
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_permissions

  # also validates level to be one of in:
  enumerize :level, in: AccessLevel.permission_strings, predicates: true, message: '\'%{value.inspect}\' is not a valid level'

  # association validations
  validates :project, existence: true
  validates :creator, existence: true

  # attribute validations
  # CREATE UNIQUE INDEX permissions_idx ON permissions(project_id, user_id) WHERE user_id IS NOT NULL
  validates :project_id, uniqueness: {scope: [:user_id], message: '\'%{value}\' does not have a unique user id'}, unless: Proc.new { |a| a.user_id.blank? }
  # CREATE UNIQUE INDEX permissions_idx ON permissions(project_id, logged_in_user) WHERE logged_in_user = TRUE
  validates :project_id, uniqueness: {scope: [:logged_in_user], message: '\'%{value}\' does not have a unique logged in user setting'}, if: Proc.new { |a| a.logged_in_user }
  # CREATE UNIQUE INDEX permissions_idx ON permissions(project_id, anonymous_user) WHERE anonymous_user = TRUE
  validates :project_id, uniqueness: {scope: [:anonymous_user], message: '\'%{value}\' does not have a unique anonymous user setting'}, if: Proc.new { |a| a.anonymous_user }
  validates_presence_of :level, :creator, :project

  validate :mutually_exclusive_settings, :invalid_permissions

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

  private

  def mutually_exclusive_settings
    anonymous_user_value = self.anonymous_user # true or false
    logged_in_user_value = self.logged_in_user # true or false
    user_id_value = !self.user_id.nil? # integer or nil

    if !anonymous_user_value && !logged_in_user_value && !user_id_value
      errors.add(:user_id, 'must be set if anonymous user and logged in user are false')
    elsif anonymous_user_value && logged_in_user_value
      errors.add(:anonymous_user, 'can\'t be true when logged in user is true')
      errors.add(:logged_in_user, 'can\'t be true when anonymous user is true')
    elsif anonymous_user_value && user_id_value
      errors.add(:anonymous_user, 'can\'t be true when user id is set')
      errors.add(:user_id, 'can\'t be true when anonymous user is true')
    elsif logged_in_user_value && user_id_value
      errors.add(:logged_in_user, 'can\'t be true when user id is set')
      errors.add(:user_id, 'can\'t be true when logged in user is true')
    end

  end

  def invalid_permissions
    level_value = self.level

    # only users can be owners
    errors.add(:anonymous_user, 'can\'t be true when level is :owner') if level_value == 'owner' && self.anonymous_user
    errors.add(:logged_in_user, 'can\'t be true when level is :owner') if level_value == 'owner' && self.logged_in_user
  end
end