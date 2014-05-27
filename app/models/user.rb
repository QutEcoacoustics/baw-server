require 'role_model'

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :token_authenticatable, :confirmable, :lockable, :timeoutable

  # http://www.phase2technology.com/blog/authentication-permissions-and-roles-in-rails-with-devise-cancan-and-role-model/
  include RoleModel

  attr_accessible :user_name, :email, :password, :password_confirmation, :remember_me,
                  :roles, :roles_mask, :preferences,
                  :image

  roles :admin, :user, :harvester # do not change the order, it matters!

  model_stamper # this identifies this class as being the class that 'stamps'

  has_attached_file :image,
                    styles: {span4: '300x300#', span3: '220x220#', span2: '140x140#', span1: '60x60#', spanhalf: '30x30#'},
                    default_url: '/images/user/user_:style.png'

  # relations
  has_many :accessible_projects, through: :permissions, source: :project
  has_many :readable_projects, through: :permissions, source: :project, conditions: 'permissions.level = reader'
  has_many :writable_projects, through: :permissions, source: :project, conditions: 'permissions.level = writer'

  # relations for creator, updater, deleter, and others.
  has_many :created_audio_events, class_name: 'AudioEvent', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_audio_events, class_name: 'AudioEvent', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_audio_events, class_name: 'AudioEvent', foreign_key: :deleter_id, inverse_of: :deleter

  has_many :created_audio_recordings, class_name: 'AudioRecording', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_audio_recordings, class_name: 'AudioRecording', foreign_key: :updater_id, inverse_of: :updater
  has_many :deleted_audio_recordings, class_name: 'AudioRecording', foreign_key: :deleter_id, inverse_of: :deleter
  has_many :uploaded_audio_recordings, class_name: 'AudioRecording', foreign_key: :uploader_id, inverse_of: :uploader

  has_many :created_taggings, class_name: 'Tagging', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_taggings, class_name: 'Tagging', foreign_key: :updater_id, inverse_of: :updater

  has_many :created_bookmarks, class_name: 'Bookmark', foreign_key: :creator_id, inverse_of: :creator
  has_many :updated_bookmarks, class_name: 'Bookmark', foreign_key: :updater_id, inverse_of: :updater

  has_many :created_datasets, class_name: 'Dataset', foreign_key: :creator_id, inverse_of: :creator, include: :project
  has_many :updated_datasets, class_name: 'Dataset', foreign_key: :updater_id, inverse_of: :updater, include: :project

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
  validates :user_name, presence: true, uniqueness: {case_sensitive: false}
  validates :email, presence: true, uniqueness: true
  validates :roles_mask, presence: true
  validates_attachment_content_type :image, content_type: /^image\/(jpg|jpeg|pjpeg|png|x-png|gif)$/, message: 'file type %{value} is not allowed (only jpeg/png/gif images)'

  # before and after methods
  before_validation :ensure_user_role

  after_create :special_after_create_actions

  def projects
    (self.created_projects.includes(:sites) + self.accessible_projects.includes(:sites)).uniq
  end

  def inaccessible_projects
    user_projects = self.projects.map { |project| project.id }

    Project
    .where('id NOT IN (?)', (user_projects.blank? ? '0' : user_projects))
    .order(:name)
    .uniq
  end

  def recently_updated_projects
    # .includes() for left outer join
    # .joins for inner join
    creator_id_check = 'projects.creator_id = ?'
    permissions_check = '(permissions.user_id = ? AND permissions.level IN (\'reader\', \'writer\'))'
    Project.includes(:permissions).where("(#{creator_id_check} OR #{permissions_check})", self.id, self.id).uniq.order('projects.updated_at DESC').limit(10)
  end

  def recently_added_audio_events(page = 1, per_page = 30)
    AudioEvent
    .includes(:audio_recording)
    .where('creator_id = ? OR updater_id = ?', self.id, self.id)
    .uniq
    .order('audio_events.updated_at DESC')
    .paginate(page: page, per_page: per_page)
  end

  def accessible_audio_recordings
    user_sites = self.projects.map { |project| project.sites.map { |site| site.id } }.to_a.uniq
    AudioRecording.where(site_id: user_sites).limit(10)
  end

  def accessible_audio_events
    user_sites = self.projects.map { |project| project.sites.select(:id).map { |site| site.id } }.to_a.uniq
    AudioEvent.where(audio_recording_id: AudioRecording.where(site_id: user_sites).select(:id)).limit(10)
  end

  # helper methods for permission checks

  # @param [Project] project
  def can_read?(project)
    !Permission.find_by_user_id_and_project_id_and_level(self, project, 'reader').blank? || project.creator == self
  end

  # @param [Project] project
  def can_write?(project)
    !Permission.find_by_user_id_and_project_id_and_level(self, project, 'writer').blank? || project.creator == self
  end

  # @param [Array<Project>] projects
  def can_write_any?(projects)
    projects.each do |project|
      if self.can_write?(project)
        return true
      end
    end
    false
  end

  # @param [Project] project
  def highest_permission(project)
    # low to high: none, read, write, creator/owner, admin
    if self.has_role? :admin
      AccessLevel::ADMIN
    elsif project.creator == self
      AccessLevel::OWNER
    elsif self.can_write? project
      AccessLevel::WRITE
    elsif self.can_read? project
      AccessLevel::READ
    else
      AccessLevel::NONE
    end
  end

  # @param [Array<Project>] projects
  def highest_permission_any(projects)
    highest = 0
    projects.each do |project|
      permission = self.highest_permission(project)
      if permission > highest
        highest = permission
      end
    end
    highest
  end

  # @param [Project] project
  def has_permission?(project)
    !Permission.find_by_user_id_and_project_id(self, project).blank? || project.creator == self
  end

  # @param [Array<Project>] projects
  def has_permission_any?(projects)
    projects.each do |project|
      if self.has_permission?(project)
        return true
      end
    end
    false
  end

  # @param [Project] project
  def get_read_permission(project)
    Permission.find_by_user_id_and_project_id_and_level(self, project, 'reader')
  end

  # @param [Project] project
  def get_write_permission(project)
    Permission.find_by_user_id_and_project_id_and_level(self, project, 'writer')
  end

  # @param [Project] project
  def get_permission(project)
    Permission.find_by_user_id_and_project_id(self, project)
  end

  private
  def ensure_user_role
    self.roles << :user if roles_mask.blank?
  end


  def special_after_create_actions
    # WARNING: if this raises an error, the user will not be created and the page will be redirected to the home page
    # notify us of new user sign ups
    PublicMailer.new_user_message(self, NewUserInfo.new(name: self.user_name, email: self.email))

    # add this hack only for a short time
    # new users are automatically confirmed
    self.confirmation_token = nil
    self.skip_confirmation!
    self.save!

    # add this hack only for a short time
    # new users get access to this project straight away

    special_project_id = 1007
    project_id = special_project_id unless Project.where(id: special_project_id).first.blank?

    unless project_id.blank?
      new_permission = Permission.new(creator_id: self.id, level: :writer, project_id: project_id, user_id: self.id)
      new_permission.save!
    end
  end
end
