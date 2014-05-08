class Site < ActiveRecord::Base
  attr_accessible :name, :latitude, :longitude, :description, :image, :project_ids, :notes

  attr_reader :location_obfuscated

  # relations
  has_and_belongs_to_many :projects, uniq: true
  has_and_belongs_to_many :datasets, uniq: true
  has_many :audio_recordings, inverse_of: :site

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_sites
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_sites
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_sites

  has_attached_file :image,
                    styles: {span4: '300x300#', span3: '220x220#', span2: '140x140#', span1: '60x60#', spanhalf: '30x30#'},
                    default_url: '/images/site/site_:style.png'

  LATITUDE_MIN = -90
  LATITUDE_MAX = 90
  LONGITUDE_MIN = -180
  LONGITUDE_MAX = 180

  JITTER_RANGE = 0.0002

  # add created_at and updated_at stamper
  stampable

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  acts_as_gmappable process_geocoding: false

  # validations
  validates :name, presence: true, length: {minimum: 2}
  # between -90 and 90 degrees
  validates :latitude, numericality: {only_integer: false, greater_than_or_equal_to: Site::LATITUDE_MIN, less_than_or_equal_to: Site::LATITUDE_MAX,
                                      message: "%{value} must be greater than or equal to #{Site::LATITUDE_MIN} and less than or equal to #{Site::LATITUDE_MAX}"}, allow_nil: true

  # -180 and 180 degrees
  validates :longitude, numericality: {only_integer: false, greater_than_or_equal_to: Site::LONGITUDE_MIN, less_than_or_equal_to: Site::LONGITUDE_MAX,
                                       message: "%{value} must be greater than or equal to #{Site::LONGITUDE_MIN} and less than or equal to #{Site::LONGITUDE_MAX}"}, allow_nil: true

  validates_attachment_content_type :image, content_type: /^image\/(jpg|jpeg|pjpeg|png|x-png|gif)$/, message: 'file type %{value} is not allowed (only jpeg/png/gif images)'

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
      Site.add_location_jitter(value, Site::LATITUDE_MIN, Site::LATITUDE_MAX)
    else
      value
    end
  end

  def longitude
    value = read_attribute(:longitude)
    if self.location_obfuscated && !value.blank?
      Site.add_location_jitter(value, Site::LONGITUDE_MIN, Site::LONGITUDE_MAX)
    else
      value
    end
  end

  def update_location_obfuscated(current_user)
    highest_permission = current_user.highest_permission_any(self.projects)
    @location_obfuscated = highest_permission < AccessLevel::OWNER
  end

  def self.add_location_jitter(value, min, max)
    # truncate to 4 decimal places, then add random jitter
    # that has been truncated to 5 decimal places
    # http://en.wikipedia.org/wiki/Decimal_degrees#Precision
    # add or subtract between ~4m - ~20m jitter

    truncate_decimals_4 = 10000.0
    truncated_value = (value * truncate_decimals_4).floor / truncate_decimals_4

    truncate_decimals_5 = 100000.0
    random_jitter = rand(-Site::JITTER_RANGE..Site::JITTER_RANGE)
    truncated_jitter = (random_jitter * truncate_decimals_5).floor / truncate_decimals_5

    modified_value = truncated_value + truncated_jitter

    # ensure range is maintained (damn floating point in-exactness)
    modified_value = modified_value.round(5)

    # ensure range is maintained (damn floating point in-exactness)
    if modified_value > (value + Site::JITTER_RANGE)
      modified_value = value + Site::JITTER_RANGE
    end

    if modified_value < (value - Site::JITTER_RANGE)
      modified_value = value - Site::JITTER_RANGE
    end

    # ensure modified value stays within lat/long valid ranges
    if modified_value > max
      modified_value = max
    end

    if modified_value < min
      modified_value = min
    end

    modified_value
  end
end
