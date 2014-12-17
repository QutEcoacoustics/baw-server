class Permission < ActiveRecord::Base
  extend Enumerize

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  attr_accessible :level, :project_id, :user_id, :logged_in_user, :anonymous_user

  belongs_to :project, inverse_of: :permissions
  belongs_to :user
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_permissions
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_permissions

  enumerize :level, in: AccessLevel.permission_strings, predicates: true

  # association validations
  validates :project, existence: true
  validates :creator, existence: true

  # attribute validations
  validates :level, uniqueness: { scope: [:user_id, :project_id] }
  validates :level, uniqueness: { scope: [:logged_in_user, :project_id] }
  validates :level, uniqueness: { scope: [:anonymous_user, :project_id] }
  validates_presence_of :level, :creator, :project
  validates :level, inclusion: { in: AccessLevel.permission_strings, message: '%{value} is not a valid level'}

  validate :mutually_exclusive_settings

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

    values = [anonymous_user_value, logged_in_user_value, user_id_value]

    # count the number of true values
    is_true_count = values.count(true)


    # there should be only one non-null value
    if is_true_count != 1
      msg = 'A permission can store only one of ' +
          "'anonymous_user' (set to #{self.anonymous_user}), "+
          "'logged_in_user' (set to #{self.logged_in_user}), "+
          "and 'user_id' (set to #{self.user_id})."
      fail ActiveRecord::RecordNotUnique, msg
    end

  end
end