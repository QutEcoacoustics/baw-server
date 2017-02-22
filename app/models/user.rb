require 'role_model'

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable, :lockable, :timeoutable

  # http://www.phase2technology.com/blog/authentication-permissions-and-roles-in-rails-with-devise-cancan-and-role-model/
  include RoleModel

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # ensures that this model can be archived, but not deleted
  include ModelArchive

  # user must always have an authentication token
  before_save :ensure_authentication_token

  # Virtual attribute for authenticating by either :user_name or :email
  # This is in addition to real persisted fields.
  def login=(login)
    @login = login
  end

  def login
    @login || self.user_name || self.email
  end

  # if you want to use a different integer attribute to store the
  # roles in, set it with roles_attribute :my_roles_attribute,
  # :roles_mask is the default name
  roles_attribute :roles_mask

  # declare the valid roles -- do not change the order if you add more
  # roles later, always append them at the end!
  roles :admin, :user, :harvester, :guest

  has_attached_file :image,
                    styles: {span4: '300x300#', span3: '220x220#', span2: '140x140#', span1: '60x60#', spanhalf: '30x30#'},
                    default_url: '/images/user/user_:style.png'

  # relations
  # Don't include the catch-all association to permissions
  #has_many :accessible_projects, through: :permissions, source: :project
  has_many :readable_projects, -> { where("permissions.level = 'reader'") }, through: :permissions, source: :project
  has_many :writable_projects, -> { where("permissions.level = 'writer'") }, through: :permissions, source: :project
  has_many :owned_projects, -> { where("permissions.level = 'owner'") }, through: :permissions, source: :project

  # for acts_as_paranoid
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_users

  # relations for creator, updater, deleter, and others.
  has_many :created_audio_events, class_name: 'AudioEvent', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_audio_events, class_name: 'AudioEvent', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_audio_events, class_name: 'AudioEvent', foreign_key: :deleter_id, inverse_of: :deleter

  has_many :created_audio_event_comments, class_name: 'AudioEventComment', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_audio_event_comments, class_name: 'AudioEventComment', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_audio_event_comments, class_name: 'AudioEventComment', foreign_key: :deleter_id, inverse_of: :deleter
  has_many :flagged_audio_event_comments, class_name: 'AudioEventComment', foreign_key: :flagger_id, inverse_of: :flagger

  has_many :created_audio_recordings, class_name: 'AudioRecording', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_audio_recordings, class_name: 'AudioRecording', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_audio_recordings, class_name: 'AudioRecording', foreign_key: :deleter_id, inverse_of: :deleter
  has_many :uploaded_audio_recordings, class_name: 'AudioRecording', foreign_key: :uploader_id, inverse_of: :uploader

  has_many :created_taggings, class_name: 'Tagging', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_taggings, class_name: 'Tagging', foreign_key: :updater_id, inverse_of: :updater

  has_many :created_bookmarks, class_name: 'Bookmark', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_bookmarks, class_name: 'Bookmark', foreign_key: :updater_id, inverse_of: :updater

  has_many :created_saved_searches, -> { includes :project }, class_name: 'SavedSearch', foreign_key: :creator_id, inverse_of: :creator
  has_many :deleted_saved_searches, -> { includes :project }, class_name: 'SavedSearch', foreign_key: :deleter_id, inverse_of: :deleter

  has_many :created_analysis_jobs, class_name: 'AnalysisJob', foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy
  has_many :updated_analysis_jobs, class_name: 'AnalysisJob', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_analysis_jobs, class_name: 'AnalysisJob', foreign_key: :deleter_id, inverse_of: :deleter

  has_many :permissions, inverse_of: :user, dependent: :destroy
  has_many :created_permissions, class_name: 'Permission', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_permissions, class_name: 'Permission', foreign_key: :updater_id, inverse_of: :updater

  has_many :created_projects, class_name: 'Project', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_projects, class_name: 'Project', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_projects, class_name: 'Project', foreign_key: :deleter_id, inverse_of: :deleter

  has_many :created_scripts, class_name: 'Script', foreign_key: :creator_id, inverse_of: :creator

  has_many :created_sites, class_name: 'Site', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_sites, class_name: 'Site', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_sites, class_name: 'Site', foreign_key: :creator_id, inverse_of: :deleter

  has_many :created_tags, class_name: 'Tag', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_tags, class_name: 'Tag', foreign_key: :updater_id, inverse_of: :updater

  has_many :created_tag_groups, class_name: 'TagGroup', foreign_key: :creator_id, inverse_of: :creator

  # for acts_as_paranoid
  has_many :deleted_users, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleter

  # scopes
  scope :users, -> { where(roles_mask: 2) }

  # store preferences as json in a text column
  serialize :preferences, JSON

  # validations
  validates :user_name,
            presence: true,
            uniqueness: {case_sensitive: false},
            format: {
                with: /\A[a-zA-Z0-9 _-]+\z/,
                message: 'Only letters, numbers, spaces ( ), underscores (_) and dashes (-) are valid.'
            },
            if: Proc.new { |user| user.user_name_changed? }

  validate :excluded_login, on: :create

  def excluded_login
    reserved_user_names = %w(admin harvester analysis_runner root superuser administrator admins administrators)
    self.errors.add(:login, 'is reserved') if reserved_user_names.include?(self.login.downcase)
    self.errors.add(:user_name, 'is reserved') if reserved_user_names.include?(self.user_name.downcase)
  end

  # format, uniqueness, and presence are validated by devise
  # Validatable component
  # validates :email,
  #           presence: true,
  #           uniqueness: true,
  #           format: {with:VALID_EMAIL_REGEX, message: 'Basic email validation failed. It should have at least 1 `@` and 1 `.`'}

  validates :roles_mask, presence: true
  validates_attachment_content_type :image, content_type: /^image\/(jpg|jpeg|pjpeg|png|x-png|gif)$/, message: 'file type %{value} is not allowed (only jpeg/png/gif images)'

  # before and after methods
  before_validation :ensure_user_role

  after_create :special_after_create_actions

  validate :check_tz
  before_save :set_rails_tz, if: Proc.new { |user| user.tzinfo_tz_changed? }

  # Get the last time this user was seen.
  # @return [DateTime] Date this user was last seen
  def get_last_seen
    last_seen = self.last_seen_at
    last_seen = self.current_sign_in_at if last_seen.blank?
    last_seen = self.last_sign_in_at if last_seen.blank?
    last_seen
  end

  # Length of time this person has been a member.
  # @return [DateTime] Membership duration
  def get_membership_duration
    Time.zone.now - self.created_at
  end

  def ensure_authentication_token
    if authentication_token.blank?
      self.authentication_token = generate_authentication_token
    end
  end

  def reset_authentication_token!
    self.authentication_token = generate_authentication_token
    save
  end

  def active_for_authentication?
    super && !self.deleted?
  end

  def self.same_user?(user1, user2)
    if user1.blank? || user2.blank?
      false
    else
      user1 == user2
    end
  end

  def self.profile_paths(user)
    [Api::UrlHelpers.my_account_path, Api::UrlHelpers.user_account_path(user)]
  end

  def self.profile_edit_paths(user)
    [Api::UrlHelpers.edit_user_registration_path, Api::UrlHelpers.edit_user_account_path(user)]
  end

  # Change the behaviour of the auth action to use :login rather than :email.
  # Because we want to change the behavior of the login action, we have to overwrite
  # the find_for_database_authentication method. The method's stack works like this:
  # find_for_database_authentication calls find_for_authentication which calls
  # find_first_by_auth_conditions. Overriding the find_for_database_authentication
  # method allows you to edit database authentication; overriding find_for_authentication
  # allows you to redefine authentication at a specific point (such as token, LDAP or database).
  # Finally, if you override the find_first_by_auth_conditions method, you can customize
  # finder methods (such as authentication, account unlocking or password recovery).
  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    login = conditions.delete(:login)
    if login
      where(conditions)
          .where(['lower(user_name) = :value OR lower(email) = :value', {value: login.downcase}])
          .first
    else
      where(conditions).first
    end
  end

  # @see http://stackoverflow.com/a/19071745/31567
  def self.find_by_authentication_token(authentication_token = nil)
    if authentication_token
      where(authentication_token: authentication_token).first
    end
  end

  # Store the current_user id in the thread so it can be accessed by models
  def self.stamper=(object)
    object_stamper = object.is_a?(ActiveRecord::Base) ? object.send("#{object.class.primary_key}".to_sym) : object
    Thread.current["#{self.to_s.downcase}_#{self.object_id}_stamper"] = object_stamper
  end

  # Retrieves the existing stamper (current_user id) for the current request.
  def self.stamper
    Thread.current["#{self.to_s.downcase}_#{self.object_id}_stamper"]
  end

  def self.archived_user_name
    '(archived user)'
  end

  # Define filter api settings
  def self.filter_settings
    {
        valid_fields: [:id, :user_name, :roles_mask, :last_seen_at, :created_at, :updated_at],
        render_fields: [:id, :user_name, :roles_mask],
        text_fields: [:user_name],
        custom_fields: lambda { |item, user|
          # 'item' is the user being processed, 'user' is the currently logged in user
          is_admin = Access::Core.is_admin?(user)
          is_same_user = item == user

          # do a query for the attributes that may not be in the projection
          # instance or id can be nil
          fresh_user = User.find(item.id)

          user_hash =
              {
                  timezone_information: TimeZoneHelper.info_hash(fresh_user),
                  roles_mask_names: fresh_user.roles,
                  image_urls:
                      [
                          {size: :extralarge, url: fresh_user.image.url(:span4), width: 300, height: 300},
                          {size: :large, url: fresh_user.image.url(:span3), width: 220, height: 220},
                          {size: :medium, url: fresh_user.image.url(:span2), width: 140, height: 140},
                          {size: :small, url: fresh_user.image.url(:span1), width: 60, height: 60},
                          {size: :tiny, url: fresh_user.image.url(:spanhalf), width: 30, height: 30}
                      ]
              }

          if is_admin || is_same_user
            user_hash[:last_seen_at] = fresh_user.last_seen_at
            user_hash[:preferences] = fresh_user.preferences
          end

          if is_admin
            user_hash[:is_confirmed] = fresh_user.confirmed?
          end

          [item, user_hash]
        },
        controller: :user_accounts,
        action: :filter,
        defaults: {
            order_by: :user_name,
            direction: :asc
        }
    }
  end

  private
  def ensure_user_role
    self.roles << :user if roles_mask.blank?
  end


  def special_after_create_actions
    # WARNING: if this raises an error, the user will not be created and the page will be redirected to the home page
    # notify us of new user sign ups
    user_info_hash = {name: self.user_name, email: self.email}
    user_info = DataClass::NewUserInfo.new(user_info_hash)
    PublicMailer.new_user_message(self, user_info).deliver_now
  end

  def generate_authentication_token
    loop do
      token = Devise.friendly_token
      break token unless User.where(authentication_token: token).first
    end
  end

  def set_rails_tz
    TimeZoneHelper.set_rails_tz(self)
  end

  def check_tz
    TimeZoneHelper.validate_tzinfo_tz(self)
  end

end