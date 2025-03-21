# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                                                            :integer          not null, primary key
#  authentication_token                                          :string
#  confirmation_sent_at                                          :datetime
#  confirmation_token                                            :string
#  confirmed_at                                                  :datetime
#  contactable(Is the user contactable for email communications) :enum             default("unasked"), not null
#  current_sign_in_at                                            :datetime
#  current_sign_in_ip                                            :string
#  email                                                         :string           not null
#  encrypted_password                                            :string           not null
#  failed_attempts                                               :integer          default(0)
#  image_content_type                                            :string
#  image_file_name                                               :string
#  image_file_size                                               :bigint
#  image_updated_at                                              :datetime
#  invitation_token                                              :string
#  last_seen_at                                                  :datetime
#  last_sign_in_at                                               :datetime
#  last_sign_in_ip                                               :string
#  locked_at                                                     :datetime
#  preferences                                                   :text
#  rails_tz                                                      :string(255)
#  remember_created_at                                           :datetime
#  reset_password_sent_at                                        :datetime
#  reset_password_token                                          :string
#  roles_mask                                                    :integer
#  sign_in_count                                                 :integer          default(0)
#  tzinfo_tz                                                     :string(255)
#  unconfirmed_email                                             :string
#  unlock_token                                                  :string
#  user_name                                                     :string           not null
#  created_at                                                    :datetime
#  updated_at                                                    :datetime
#
# Indexes
#
#  index_users_on_authentication_token  (authentication_token) UNIQUE
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  users_user_name_unique               (user_name) UNIQUE
#
require 'role_model'

class User < ApplicationRecord
  ADMIN_USER_NAME = 'Admin'
  HARVESTER_USER_NAME = 'Harvester'

  # ensures timezones are handled consistently
  include TimeZoneAttribute

  attr_accessor :skip_creation_email

  # Include default devise modules. Others available are:
  # and :omniauthable
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :trackable, :validatable,
    :confirmable, :lockable, :timeoutable

  # Defines a reusable mapping (CONSENT_ENUM) of consent constants
  CONSENT_UNASKED = 'unasked'
  CONSENT_YES = 'yes'
  CONSENT_NO = 'no'

  CONSENT_ENUM = {
    CONSENT_UNASKED => CONSENT_UNASKED,
    CONSENT_YES => CONSENT_YES,
    CONSENT_NO => CONSENT_NO
  }.freeze

  # @!method contactable_unasked?
  #   @return [Boolean] true if the user has not been asked for consent for contact
  # @!method contactable_unasked!
  #   @return [void] sets contactable as unasked
  # @!method contactable_yes?
  #   @return [Boolean] true if the user has consented to be contacted
  # @!method contactable_yes!
  #   @return [void] sets the user as contactable
  # @!method contactable_no?
  #   @return [Boolean] true if the user has not consented to be contacted
  # @!method contactable_no!
  #   @return [void] sets the user as not contactable
  enum :contactable, CONSENT_ENUM, prefix: :contactable, validate: true

  # @return [Boolean] true if the user has consented to be contacted
  def contactable?
    contactable == CONSENT_YES
  end

  # http://www.phase2technology.com/blog/authentication-permissions-and-roles-in-rails-with-devise-cancan-and-role-model/
  include RoleModel

  # before and after methods
  before_validation :ensure_user_role
  # user must always have an authentication token
  after_create :ensure_authentication_token

  # Virtual attribute for authenticating by either :user_name or :email
  # This is in addition to real persisted fields.
  attr_writer :login

  def login
    @login || user_name || email
  end

  # if you want to use a different integer attribute to store the
  # roles in, set it with roles_attribute :my_roles_attribute,
  # :roles_mask is the default name
  roles_attribute :roles_mask

  # declare the valid roles -- do not change the order if you add more
  # roles later, always append them at the end!
  roles :admin, :user, :harvester, :guest

  has_attached_file :image,
    styles: { span4: '300x300#', span3: '220x220#', span2: '140x140#', span1: '60x60#',
              spanhalf: '30x30#' },
    default_url: '/images/user/user_:style.png'

  # relations
  # Don't include the catch-all association to permissions
  #has_many :accessible_projects, through: :permissions, source: :project
  has_many :readable_projects, -> { where("permissions.level = 'reader'") }, through: :permissions, source: :project
  has_many :writable_projects, -> { where("permissions.level = 'writer'") }, through: :permissions, source: :project
  has_many :owned_projects, -> { where("permissions.level = 'owner'") }, through: :permissions, source: :project

  # relations for creator, updater, deleter, and others.
  has_many :created_audio_events, class_name: 'AudioEvent', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_audio_events, class_name: 'AudioEvent', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_audio_events, class_name: 'AudioEvent', foreign_key: :deleter_id, inverse_of: :deleter

  has_many :created_audio_event_imports, class_name: 'AudioEventImport', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_audio_event_imports, class_name: 'AudioEventImport', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_audio_event_imports, class_name: 'AudioEventImport', foreign_key: :deleter_id, inverse_of: :delete

  has_many :created_audio_event_comments, class_name: 'AudioEventComment', foreign_key: :creator_id,
    inverse_of: :creator
  has_many :updated_audio_event_comments, class_name: 'AudioEventComment', foreign_key: :updater_id,
    inverse_of: :updater
  has_many :deleted_audio_event_comments, class_name: 'AudioEventComment', foreign_key: :deleter_id,
    inverse_of: :deleter
  has_many :flagged_audio_event_comments, class_name: 'AudioEventComment', foreign_key: :flagger_id,
    inverse_of: :flagger

  has_many :created_audio_recordings, class_name: 'AudioRecording', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_audio_recordings, class_name: 'AudioRecording', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_audio_recordings, class_name: 'AudioRecording', foreign_key: :deleter_id, inverse_of: :deleter
  has_many :uploaded_audio_recordings, class_name: 'AudioRecording', foreign_key: :uploader_id, inverse_of: :uploader

  has_many :created_taggings, class_name: 'Tagging', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_taggings, class_name: 'Tagging', foreign_key: :updater_id, inverse_of: :updater

  has_many :created_bookmarks, class_name: 'Bookmark', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_bookmarks, class_name: 'Bookmark', foreign_key: :updater_id, inverse_of: :updater

  has_many :created_saved_searches, lambda {
                                      includes :project
                                    }, class_name: 'SavedSearch', foreign_key: :creator_id, inverse_of: :creator
  has_many :deleted_saved_searches, lambda {
                                      includes :project
                                    }, class_name: 'SavedSearch', foreign_key: :deleter_id, inverse_of: :deleter

  has_many :created_analysis_jobs, class_name: 'AnalysisJob', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_analysis_jobs, class_name: 'AnalysisJob', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_analysis_jobs, class_name: 'AnalysisJob', foreign_key: :deleter_id, inverse_of: :deleter

  has_many :permissions, inverse_of: :user
  has_many :created_permissions, class_name: 'Permission', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_permissions, class_name: 'Permission', foreign_key: :updater_id, inverse_of: :updater

  has_many :created_projects, class_name: 'Project', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_projects, class_name: 'Project', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_projects, class_name: 'Project', foreign_key: :deleter_id, inverse_of: :deleter

  has_many :created_regions, class_name: 'Region', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_regions, class_name: 'Region', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_regions, class_name: 'Region', foreign_key: :deleter_id, inverse_of: :deleter

  has_many :created_harvests, class_name: 'Harvest', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_harvests, class_name: 'Harvest', foreign_key: :updater_id, inverse_of: :updater

  has_many :created_scripts, class_name: 'Script', foreign_key: :creator_id, inverse_of: :creator

  has_many :created_provenances, class_name: 'Provenance', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_provenances, class_name: 'Provenance', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_provenances, class_name: 'Provenance', foreign_key: :deleter_id, inverse_of: :deleter

  has_many :created_sites, class_name: 'Site', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_sites, class_name: 'Site', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_sites, class_name: 'Site', foreign_key: :creator_id, inverse_of: :deleter

  has_many :created_tags, class_name: 'Tag', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_tags, class_name: 'Tag', foreign_key: :updater_id, inverse_of: :updater

  has_many :created_tag_groups, class_name: 'TagGroup', foreign_key: :creator_id, inverse_of: :creator

  has_many :created_datasets, class_name: 'Dataset', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_datasets, class_name: 'Dataset', foreign_key: :updater_id, inverse_of: :updater
  has_many :created_dataset_items, class_name: 'DatasetItem', foreign_key: :creator_id, inverse_of: :creator
  has_many :created_progress_events, class_name: 'ProgressEvent', foreign_key: :creator_id, inverse_of: :creator

  has_many :created_studies, class_name: 'Study', foreign_key: :creator_id, inverse_of: :creator
  has_many :created_questions, class_name: 'Question', foreign_key: :creator_id, inverse_of: :creator
  has_many :created_responses, class_name: 'Response', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_studies, class_name: 'Study', foreign_key: :updater_id, inverse_of: :updater
  has_many :updated_questions, class_name: 'Question', foreign_key: :updater_id, inverse_of: :updater

  has_one :statistics, class_name: Statistics::UserStatistics.name

  has_many :created_verifications, class_name: 'Verification', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_verifications, class_name: 'Verification', foreign_key: :updator_id, inverse_of: :updater

  # scopes
  scope :users, -> { where(roles_mask: 2) }
  scope(:recently_seen,
    lambda { |time|
      where(
        (arel_table[:last_seen_at] > time)
        .or(arel_table[:current_sign_in_at] > time)
        .or(arel_table[:last_sign_in_at] > time)
      )
    })

  # store preferences as json in a text column
  serialize :preferences, coder: JSON

  # validations
  validates :user_name,
    presence: true,
    uniqueness: { case_sensitive: false },
    format: {
      with: /\A[a-zA-Z0-9 _-]+\z/,
      message: 'Only letters, numbers, spaces ( ), underscores (_) and dashes (-) are valid.'
    },
    if: proc { |user| user.user_name_changed? }

  validate :excluded_login, on: :create

  def excluded_login
    reserved_user_names = ['admin', 'harvester', 'analysis_runner', 'root', 'superuser', 'administrator', 'admins',
                           'administrators']
    errors.add(:login, 'is reserved') if reserved_user_names.include?(login&.downcase)
    errors.add(:user_name, 'is reserved') if reserved_user_names.include?(user_name&.downcase)
  end

  # format, uniqueness, and presence are validated by devise
  # Validatable component
  # validates :email,
  #           presence: true,
  #           uniqueness: true,
  #           format: {with:VALID_EMAIL_REGEX, message: 'Basic email validation failed. It should have at least 1 `@` and 1 `.`'}

  validates :roles_mask, presence: true
  validates_attachment_content_type :image, content_type: %r{^image/(jpg|jpeg|pjpeg|png|x-png|gif)$},
    message: 'file type %<value>s is not allowed (only jpeg/png/gif images)'

  after_create :special_after_create_actions

  # get's a file system safe ([-A-Za-z0-9_]) version of the user name
  # @return [String]
  def safe_user_name
    user_name
      .gsub("'", '')
      .gsub(/[^-_A-Za-z0-9]+/, '-')
      .delete_prefix('-')
      .delete_suffix('-')
  end

  # Get the last time this user was seen.
  # @return [DateTime] Date this user was last seen
  def get_last_seen
    last_seen = last_seen_at
    last_seen = current_sign_in_at if last_seen.blank?
    last_seen = last_sign_in_at if last_seen.blank?
    last_seen
  end

  # Length of time this person has been a member.
  # @return [DateTime] Membership duration
  def get_membership_duration
    Time.zone.now - created_at
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
  # https://github.com/heartcombo/devise/wiki/How-To:-Allow-users-to-sign-in-using-their-username-or-email-address
  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    if (login = conditions.delete(:login))
      where(conditions.to_h)
        .where(['lower(user_name) = :value OR lower(email) = :value', { value: login.downcase }])
        .first
    else
      where(conditions.to_h).first
    end
  end

  def after_database_authentication
    # Generate a new authentication token if the current one is expired.
    # We're only here after a successful login from other means.
    reset_authentication_token! if expired_authentication_token?
  end

  def ensure_authentication_token
    self.authentication_token = generate_authentication_token if authentication_token.blank?

    authentication_token
  end

  def reset_authentication_token!
    self.authentication_token = generate_authentication_token
    save!
  end

  def clear_authentication_token!
    self.authentication_token = nil
    save!
  end

  def expired_authentication_token?
    return true if authentication_token.blank?

    last_activity = [current_sign_in_at, last_sign_in_at, last_seen_at].compact.max

    # we can have no activity for brand new users, in which case the token is not expired
    return false if last_activity.nil?

    time_since = Time.zone.now - last_activity
    time_since > Settings.authentication.token_rolling_expiration
  end

  # Store the current_user id in the thread so it can be accessed by models
  def self.stamper=(object)
    object_stamper = object.is_a?(ActiveRecord::Base) ? object.send(object.class.primary_key.to_s.to_sym) : object
    Thread.current["#{to_s.downcase}_#{object_id}_stamper"] = object_stamper
  end

  # Retrieves the existing stamper (current_user id) for the current request.
  def self.stamper
    Thread.current["#{to_s.downcase}_#{object_id}_stamper"]
  end

  # Finds the admin user
  # @return [User]
  def self.admin_user
    # caching these values screws up the tests - we relay on AR cache instead?
    User.where(user_name: ADMIN_USER_NAME).first
  end

  # Finds the harvester user
  # @return [User]
  def self.harvester_user
    # caching these values screws up the tests - we relay on AR cache instead?
    User.where(user_name: HARVESTER_USER_NAME).first
  end

  def admin?
    Access::Core.is_admin?(self)
  end

  # Define filter api settings
  # @return [Hash] filter settings
  def self.filter_settings
    {
      valid_fields: [:id, :user_name, :roles_mask, :last_seen_at, :created_at, :updated_at, :contactable],
      render_fields: [:id, :user_name, :roles_mask, :contactable],
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
                           timezone_information: fresh_user.timezone,
                           roles_mask_names: fresh_user.roles,
                           image_urls: Api::Image.image_urls(fresh_user.image)
                         }

                       if is_admin || is_same_user
                         user_hash[:last_seen_at] = fresh_user.last_seen_at
                         user_hash[:preferences] = fresh_user.preferences
                       end

                       user_hash[:is_confirmed] = fresh_user.confirmed? if is_admin

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
    roles << :user if roles_mask.blank?
  end

  def special_after_create_actions
    return if skip_creation_email

    # WARNING: if this raises an error, the user will not be created and the page will be redirected to the home page
    # notify us of new user sign ups
    user_info_hash = { name: user_name, email: }
    user_info = DataClass::NewUserInfo.new(user_info_hash)
    PublicMailer.new_user_message(self, user_info).deliver_now
  end

  def generate_authentication_token
    # loop {
    #   token = Devise.friendly_token
    #   break token unless User.where(authentication_token: token).first
    # }

    # I decided that looping through the database to check a unique token was too slow.
    # Thus we're generating a token, that is longer and all but guaranteed to be unique.
    # Basic method lifted from
    # https://github.com/heartcombo/devise/blob/6d32d2447cc0f3739d9732246b5a5bde98d9e032/lib/devise.rb#L500

    # first create some seed data
    uid = id.to_s
    timestamp = (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1E9).to_i.to_s
    random =  SecureRandom.urlsafe_base64

    # then hash it
    hashed = Digest::SHA2.digest(uid + timestamp + random)

    # and finally encode it as url safe
    Base64.urlsafe_encode64(hashed, padding: false)
  end
end
