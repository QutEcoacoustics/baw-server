require 'role_model'

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable, :lockable, :timeoutable

  # http://www.phase2technology.com/blog/authentication-permissions-and-roles-in-rails-with-devise-cancan-and-role-model/
  include RoleModel

  attr_accessible :user_name, :email, :password, :password_confirmation, :remember_me,
                  :roles, :roles_mask, :preferences,
                  :image, :login

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
  # no relations specified for projects - see AccessLevel class

  # relations for creator, updater, deleter, and others.
  has_many :created_audio_events, class_name: 'AudioEvent', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_audio_events, class_name: 'AudioEvent', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_audio_events, class_name: 'AudioEvent', foreign_key: :deleter_id, inverse_of: :deleter

  has_many :created_audio_event_comments, class_name: 'AudioEventComment', foreign_key: 'creator_id', inverse_of: :creator
  has_many :updated_audio_event_comments, class_name: 'AudioEventComment', foreign_key: 'updater_id', inverse_of: :updater
  has_many :deleted_audio_event_comments, class_name: 'AudioEventComment', foreign_key: 'deleter_id', inverse_of: :deleter
  has_many :flagged_audio_event_comments, class_name: 'AudioEventComment', foreign_key: 'flagger_id', inverse_of: :flagger

  has_many :created_audio_recordings, class_name: 'AudioRecording', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_audio_recordings, class_name: 'AudioRecording', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_audio_recordings, class_name: 'AudioRecording', foreign_key: :deleter_id, inverse_of: :deleter
  has_many :uploaded_audio_recordings, class_name: 'AudioRecording', foreign_key: :uploader_id, inverse_of: :uploader

  has_many :created_taggings, class_name: 'Tagging', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_taggings, class_name: 'Tagging', foreign_key: :updater_id, inverse_of: :updater

  has_many :created_bookmarks, class_name: 'Bookmark', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_bookmarks, class_name: 'Bookmark', foreign_key: :updater_id, inverse_of: :updater

  has_many :created_datasets, -> { includes :project }, class_name: 'Dataset', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_datasets, -> { includes :project }, class_name: 'Dataset', foreign_key: :updater_id, inverse_of: :updater

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

  def projects
    # TODO tidy up user project accessing - too many ways to do the same thing
    (self.created_projects.includes(:sites, :creator) + self.accessible_projects.includes(:sites, :creator)).uniq.sort { |a, b| a.name.downcase <=> b.name.downcase }
  end

  def inaccessible_projects
    user_projects = self.projects.map { |project| project.id }.to_a

    query = Project.all

    unless user_projects.blank?
      query = query.where('id NOT IN (?)', user_projects)
    end

    query.order(:name).uniq
  end

  def recently_updated_projects
    accessible_projects_all.uniq.limit(10)
  end

  def accessible_projects_all
    # TODO tidy up user project accessing - too many ways to do the same thing
    # .includes() for left outer join
    # .joins for inner join
    creator_id_check = 'projects.creator_id = ?'
    permissions_check = '(permissions.user_id = ? AND permissions.level IN (\'reader\', \'writer\'))'
    Project
        .includes(:permissions, :sites, :creator)
        .where("(#{creator_id_check} OR #{permissions_check})", self.id, self.id)
        .references(:permissions, :sites, :creator)
        .order('projects.name DESC')
  end

  def accessible_sites
    user_sites = self.projects.map { |project| project.sites.map { |site| site.id } }.to_a.uniq
    Site.where(id: user_sites).order('sites.name DESC')
  end

  def accessible_audio_events
    AudioEvent
        .includes(:audio_recording, :creator)
        .where(audio_recording_id: accessible_audio_recordings.select(:id))
  end

  def accessible_audio_recordings
    user_sites = self.projects.map { |project| project.sites.map { |site| site.pluck(:id) } }.to_a.uniq
    AudioRecording.where(site_id: user_sites)
  end

  def accessible_comments
    audio_events = AudioEvent.where(audio_recording_id: accessible_audio_recordings.select(:id))
    AudioEventComment.where(audio_event_id: audio_events).select(:id)
  end

  def accessible_bookmarks
    Bookmark.where(creator_id: self.id)
  end

  # Get the number of projects this user has access to.
  # @return [Integer] Number of projects.
  def get_project_count
    projects.count
  end

  # Get the number of sites this user has access to.
  # @return [Integer] Number of sites.
  def get_site_count
    projects.map { |project| project.sites.count }.reduce(0) do |result, value|
      result += value
      result
    end
  end

  # Get the number of tags this user has used.
  # @return [Integer] Number of tags.
  def get_tag_count
    Tagging.where('audio_events_tags.creator_id = ? OR audio_events_tags.updater_id = ?', self.id, self.id).count
  end

  def get_annotation_count
    AudioEvent.where('audio_events.creator_id = ? OR audio_events.updater_id = ?', self.id, self.id).count
  end

  def get_bookmark_count
    Bookmark.where('bookmarks.creator_id = ? OR bookmarks.updater_id = ?', self.id, self.id).count
  end

  def get_comment_count
    AudioEventComment.where('audio_event_comments.creator_id = ? OR audio_event_comments.updater_id = ?', self.id, self.id).count
  end

  # Get the last tiem this user was seen.
  # @return [DateTime] Date this user was last seen
  def get_last_seen
    self.current_sign_in_at.blank? ? self.last_sign_in_at : self.current_sign_in_at
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
    PublicMailer.new_user_message(self, user_info)
  end

  def generate_authentication_token
    loop do
      token = Devise.friendly_token
      break token unless User.where(authentication_token: token).first
    end
  end

end