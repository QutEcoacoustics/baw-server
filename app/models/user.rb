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
  has_many :owned_projects, class_name: 'Project', foreign_key: :creator_id
  has_many :permissions, inverse_of: :user
  has_many :accessible_projects, through: :permissions, source: :project
  has_many :readable_projects, through: :permissions, source: :project, conditions: 'permissions.level = reader'
  has_many :writable_projects, through: :permissions, source: :project, conditions: 'permissions.level = writer'
  has_many :bookmarks, foreign_key: :creator_id
  has_many :datasets, foreign_key: :creator_id, include: :project

  # scopes
  scope :users, -> { where(roles_mask: 2) }

  # store preferences as json in a text column
  serialize :preferences, JSON

  # validations
  validates :user_name, presence: true, uniqueness: {case_sensitive: false}
  validates :email, presence: true, uniqueness: true
  validates :roles_mask, presence: true
  validates_attachment_content_type :image, :content_type => /\Aimage\/.*\Z/

  # before and after methods
  before_validation :ensure_user_role

  def projects
    (self.owned_projects + self.accessible_projects).uniq
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
    Project.includes(:permissions).where("(#{creator_id_check} OR #{permissions_check})", self.id, self.id).uniq.order('projects.updated_at DESC')
  end

  def audio_events(params)
    # get a paged collection of all audio_events the current user can access
    # option params:
    # page, items, reference, tags_partial

    creator_id_check = 'projects.creator_id = ?'
    permissions_check = '(permissions.user_id = ? AND permissions.level IN (\'reader\', \'writer\'))'

    query = AudioEvent
    .includes(:tags)
    .joins(audio_recording: {site: {projects: :permissions}})

    unless self.is_admin?
      query = query.where("#{creator_id_check} OR #{permissions_check}", self.id, self.id)
    end

    if params[:reference]
      query = query.where(is_reference: params[:reference] == 'true' ? true : false)
    end

    if params[:tags_partial]
      tags_partial = CSV.parse(params[:tags_partial], col_sep: ' ').flatten.join('|').downcase

      tags_query = AudioEvent.joins(:tags).where('lower(tags.text) SIMILAR TO ?', "%(#{tags_partial})%")
      puts tags_query.explain
      query = query.where(id: tags_query.pluck(:id))
    end

    # paging and ordering
    page = 1
    if params[:page]
      page = params[:page].to_i
    end

    if page < 1
      page = 1
    end

    items = 30
    if params[:items]
      items = params[:items].to_i
    end

    if items < 1
      items = 1
    end

    if items > 30
      items = 30
    end

    query = query.offset((page - 1) * items).limit(items).order('audio_events.created_at DESC')
    puts query.explain
    query
  end

  # helper methods for permission checks
  def can_read?(project)
    !Permission.find_by_user_id_and_project_id_and_level(self, project, 'reader').blank? || project.owner == self
  end

  def can_write?(project)
    !Permission.find_by_user_id_and_project_id_and_level(self, project, 'writer').blank? || project.owner == self
  end

  def can_write_any?(projects)
    projects.each do |project|
      if self.can_write?(project)
        return true
      end
    end
    return false
  end

  def highest_permission(project)
    # low to high: none, read, write, owner, admin
    if self.has_role? :admin
      AccessLevel::ADMIN
    elsif project.owner == self
      AccessLevel::OWNER
    elsif self.can_write? project
      AccessLevel::WRITE
    elsif self.can_read? project
      AccessLevel::READ
    else
      AccessLevel::NONE
    end
  end

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

  def has_permission?(project)
    !Permission.find_by_user_id_and_project_id(self, project).blank? || project.owner == self # project.creator == self
  end

  def has_permission_any?(projects)
    projects.each do |project|
      if self.has_permission?(project)
        return true
      end
    end
    return false
  end

  def get_read_permission(project)
    Permission.find_by_user_id_and_project_id_and_level(self, project, 'reader')
  end

  def get_write_permission(project)
    Permission.find_by_user_id_and_project_id_and_level(self, project, 'writer')
  end

  def get_permission(project)
    Permission.find_by_user_id_and_project_id(self, project)
  end

  private
  def ensure_user_role
    self.roles << :user if roles_mask.blank?
  end
end
