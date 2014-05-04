class Project < ActiveRecord::Base
  attr_accessible :creator_id, :deleted_at, :deleter_id, :description, :image, :name, :notes, :updater_id, :urn

  # relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_projects
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_projects
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_projects

  has_many :permissions, inverse_of: :project
  accepts_nested_attributes_for :permissions
  has_many :readers, through: :permissions, source: :user, conditions: "permissions.level = 'reader'", uniq: true
  has_many :writers, through: :permissions, source: :user, conditions: "permissions.level = 'writer'", uniq: true
  has_and_belongs_to_many :sites, uniq: true
  has_many :datasets, inverse_of: :project
  has_many :jobs, through: :datasets

  #plugins
  has_attached_file :image,
                    styles: {span4: '300x300#', span3: '220x220#', span2: '140x140#', span1: '60x60#', spanhalf: '30x30#'},
                    default_url: '/images/project/project_:style.png'
  stampable
  acts_as_paranoid

  # validation
  validates :name, :presence => true, :uniqueness => {:case_sensitive => false}
  #validates :urn, :presence => true, :uniqueness => { :case_sensitive => false }
  #validates_format_of :urn, :with => /^urn:[a-z0-9][a-z0-9-]{0,31}:[a-z0-9()+,\-.:=@;$_!*'%\/?#]+$/
  validates_attachment_content_type :image, content_type: /^image\/(jpg|jpeg|pjpeg|png|x-png|gif)$/, message: 'file type %{value} is not allowed (only jpeg/png/gif images)'

  # scopes
  scope :none, where('1 = 0') # for getting an empty set
end
