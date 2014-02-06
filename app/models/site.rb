class Site < ActiveRecord::Base
  attr_accessible :name, :latitude, :longitude, :description, :image, :project_ids

  attr_reader :location_obfuscated

  # relations
  has_and_belongs_to_many :projects, uniq: true
  has_and_belongs_to_many :datasets, uniq: true
  has_many :audio_recordings, inverse_of: :site

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id

  has_attached_file :image,
                    styles: {span4: '300x300#', span3: '220x220#', span2: '140x140#', span1: '60x60#', spanhalf: '30x30#'},
                    default_url: '/images/site/site_:style.png'


  # acts_as_paranoid
  # userstamp
  stampable

  acts_as_gmappable process_geocoding: false

  # validations
  validates :name, presence: true, :length => {:minimum => 2}
  validates :latitude, numericality: true, :allow_nil => true
  validates :longitude, numericality: true, :allow_nil => true
  #validates_as_paranoid
  validates_attachment_content_type :image, :content_type => /\Aimage\/.*\Z/

  # commonly used queries
  #scope :specified_sites, lambda { |site_ids| where('id in (:ids)', { :ids => site_ids } ) }
  #scope :sites_in_project, lambda { |project_ids| where(Project.specified_projects, { :ids => project_ids } ) }
  #scope :site_projects, lambda{ |project_ids| includes(:projects).where(:projects => {:id => project_ids} ) }

  def project_ids
    self.projects.collect { |project| project.id }
  end

  def latitude
    value = read_attribute(:latitude)
    if self.location_obfuscated && !value.blank?
      random_num = (Random.rand * 100).round(0)
      rounded = value.round(2)
      "#{rounded}#{random_num}".to_f
    else
      value
    end
  end

  def longitude
    value = read_attribute(:longitude)
    if self.location_obfuscated && !value.blank?
      random_num = (Random.rand * 100).round(0)
      rounded = value.round(2)
      "#{rounded}#{random_num}".to_f
    else
      value
    end
  end

  def update_location_obfuscated(current_user)
    highest_permission = current_user.highest_permission_any(self.projects)
    @location_obfuscated = highest_permission < AccessLevel::OWNER
  end
end
