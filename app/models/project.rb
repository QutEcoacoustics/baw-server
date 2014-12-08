class Project < ActiveRecord::Base
  extend Enumerize
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  attr_accessible :description, :image, :name, :notes, :urn,
                  :sign_in_level, :anonymous_level

  # relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_projects
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_projects
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_projects

  has_many :permissions, inverse_of: :project
  accepts_nested_attributes_for :permissions

  has_many :readers, -> { where("permissions.level = 'reader'").uniq }, through: :permissions, source: :user
  has_many :writers, -> { where("permissions.level = 'writer'").uniq }, through: :permissions, source: :user

  has_and_belongs_to_many :sites, uniq: true
  has_many :datasets, inverse_of: :project
  has_many :jobs, through: :datasets

  SIGN_IN_LEVELS_SYM = [:none, :reader, :writer, :owner]
  SIGN_IN_LEVELS = SIGN_IN_LEVELS_SYM.map { |item| item.to_s }
  enumerize :sign_in_level, in: SIGN_IN_LEVELS, predicates: true

  ANON_LEVELS_SYM = [:none, :reader, :writer]
  ANON_LEVELS = ANON_LEVELS_SYM.map { |item| item.to_s }
  enumerize :anonymous_level, in: ANON_LEVELS, predicates: true

  #plugins
  has_attached_file :image,
                    styles: {span4: '300x300#', span3: '220x220#', span2: '140x140#', span1: '60x60#', spanhalf: '30x30#'},
                    default_url: '/images/project/project_:style.png'


  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # association validations
  validates :creator, existence: true

  # attribute validations
  validates :name, presence: true, uniqueness: {case_sensitive: false}
  #validates :urn, uniqueness: {case_sensitive: false}, allow_blank: true, allow_nil: true
  validates_format_of :urn, with: /\Aurn:[a-z0-9][a-z0-9-]{0,31}:[a-z0-9()+,\-.:=@;$_!*'%\/?#]+\z/, message: 'urn %{value} is not valid, must be in format urn:<name>:<path>', allow_blank: true, allow_nil: true
  validates_attachment_content_type :image, content_type: /\Aimage\/(jpg|jpeg|pjpeg|png|x-png|gif)\z/, message: 'file type %{value} is not allowed (only jpeg/png/gif images)'

  # Define filter api settings
  def self.filter_settings
    {
        valid_fields: [:id, :name, :description, :created_at, :creator_id],
        render_fields: [:id, :name, :description, :creator_id],
        text_fields: [:name, :description],
        controller: :projects,
        action: :filter,
        defaults: {
            order_by: :name,
            direction: :desc
        }
    }
  end
end
