require 'role_model'

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable, :lockable, :timeoutable

  # http://www.phase2technology.com/blog/authentication-permissions-and-roles-in-rails-with-devise-cancan-and-role-model/
  include RoleModel

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

  roles :admin, :user, :harvester # do not change the order, it matters!

  has_attached_file :image,
                    styles: {span4: '300x300#', span3: '220x220#', span2: '140x140#', span1: '60x60#', spanhalf: '30x30#'},
                    default_url: '/images/user/user_:style.png'

  # relations
  # Don't include the catch-all association to permissions
  #has_many :accessible_projects, through: :permissions, source: :project
  has_many :readable_projects, -> { where("permissions.level = 'reader'") }, through: :permissions, source: :project
  has_many :writable_projects, -> { where("permissions.level = 'writer'") }, through: :permissions, source: :project
  has_many :owned_projects,    -> { where("permissions.level = 'owner'") },  through: :permissions, source: :project

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

  has_many :created_jobs, class_name: 'Job', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_jobs, class_name: 'Job', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_jobs, class_name: 'Job', foreign_key: :deleter_id, inverse_of: :deleter

  has_many :permissions, inverse_of: :user
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

  # scopes
  scope :users, -> { where(roles_mask: 2) }

  # store preferences as json in a text column
  serialize :preferences, JSON

  # validations
  validates :user_name, presence: true,
            uniqueness: {
                case_sensitive: false
            },
            format: {
                with: /\A[a-zA-Z0-9 _-]+\z/,
                message: 'Only letters, numbers, spaces ( ), underscores (_) and dashes (-) are valid.'
            }

  validates :user_name,
            exclusion: {
                in: %w(admin harvester analysis_runner root superuser administrator admins administrators)
            },
            if: Proc.new { |user| user.user_name_changed? }

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
    tzInfo_id = TimeZoneHelper.to_identifier(self.tzinfo_tz)
    rails_tz_string = TimeZoneHelper.tzinfo_to_ruby(tzInfo_id)
    unless rails_tz_string.blank?
      self.rails_tz = rails_tz_string
    end
  end

end