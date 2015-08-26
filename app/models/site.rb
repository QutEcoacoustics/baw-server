class Site < ActiveRecord::Base
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  attr_accessor :project_ids, :custom_latitude, :custom_longitude, :location_obfuscated

  # relations
  has_and_belongs_to_many :projects, -> { uniq }
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

  JITTER_RANGE = 0.0005

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # association validations
  validates :creator, existence: true

  # attribute validations
  validates :name, presence: true, length: {minimum: 2}

  # between -90 and 90 degrees
  validates :latitude, numericality: {only_integer: false, greater_than_or_equal_to: Site::LATITUDE_MIN, less_than_or_equal_to: Site::LATITUDE_MAX,
                                      message: "%{value} must be greater than or equal to #{Site::LATITUDE_MIN} and less than or equal to #{Site::LATITUDE_MAX}"}, allow_nil: true

  # -180 and 180 degrees
  validates :longitude, numericality: {only_integer: false, greater_than_or_equal_to: Site::LONGITUDE_MIN, less_than_or_equal_to: Site::LONGITUDE_MAX,
                                       message: "%{value} must be greater than or equal to #{Site::LONGITUDE_MIN} and less than or equal to #{Site::LONGITUDE_MAX}"}, allow_nil: true

  validates_attachment_content_type :image, content_type: /^image\/(jpg|jpeg|pjpeg|png|x-png|gif)$/, message: 'file type %{value} is not allowed (only jpeg/png/gif images)'

  before_save :set_rails_tz, if: Proc.new { |site| site.tzinfo_tz_changed? }

  # commonly used queries
  #scope :specified_sites, lambda { |site_ids| where('id in (:ids)', { :ids => site_ids } ) }
  #scope :sites_in_project, lambda { |project_ids| where(Project.specified_projects, { :ids => project_ids } ) }
  #scope :site_projects, lambda{ |project_ids| includes(:projects).where(:projects => {:id => project_ids} ) }

  def get_bookmark
    Bookmark.where(audio_recording: self.audio_recordings).order(:updated_at).first
  end

  def most_recent_recording
    self.audio_recordings.order(recorded_date: :desc).first
  end

  def get_bookmark_or_recording
    bookmark = get_bookmark
    recording = most_recent_recording
    if !bookmark.blank?
      {
          audio_recording:bookmark.audio_recording,
          start_offset_seconds: bookmark.offset_seconds,
          source: :bookmark
      }
      elsif !recording.blank?
      {
          audio_recording:recording,
          start_offset_seconds: nil,
          source: :audio_recording
      }
    else
      nil
    end
  end

  # overrides getting, does not change setting
  def latitude
    value = read_attribute(:latitude)
    if self.location_obfuscated && !value.blank?
      Site.add_location_jitter(value, Site::LATITUDE_MIN, Site::LATITUDE_MAX)
    else
      value
    end
  end

  # overrides getting, does not change setting
  def longitude
    value = read_attribute(:longitude)
    if self.location_obfuscated && !value.blank?
      Site.add_location_jitter(value, Site::LONGITUDE_MIN, Site::LONGITUDE_MAX)
    else
      value
    end
  end

  def update_location_obfuscated(current_user)
    is_owner = Access::Check.can_any?(current_user, :owner, self.projects.includes(:creator))

    # obfuscate if level is less than owner
    @location_obfuscated = !is_owner
  end

  def self.add_location_jitter(value, min, max)

    # multiply by 10,000 to get to ~10m accuracy
    accuracy = 10000
    multiplied = (value * accuracy).floor.to_i

    # get a range for potential jitter

    max_diff =(Site::JITTER_RANGE * accuracy).floor.to_i
    range_min = multiplied - max_diff
    range_max = multiplied + max_diff

    # included range (inclusive range)
    range = (range_min..range_max).to_a

    excluded_diff = 1
    excluded_min = multiplied - excluded_diff
    excluded_max = multiplied + excluded_diff

    # excluded numbers (inclusive range)
    excluded = (excluded_min..excluded_max).to_a

    # create array of available numbers with middle range excluded
    available = range - excluded

    # select a random value from the available array of ints
    selected = available.sample

    # round to ensure precision is maintained (damn floating point in-exactness)
    # can't usually get more accurate than 5 decimal places anyway
    modified_value = (selected / accuracy).round(5)

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

  # Define filter api settings
  def self.filter_settings
    {
        valid_fields: [:id, :name, :description, :created_at, :updated_at, :project_ids],
        render_fields: [:id, :name, :description],
        text_fields: [:description, :name],
        custom_fields: lambda { |site, user|
            site.update_location_obfuscated(user)

            # do a query for the attributes that may not be in the projection
            fresh_site = Site.find(site.id)
            fresh_site.update_location_obfuscated(user)

            site_hash = {}
            site_hash[:project_ids] = fresh_site.projects.pluck(:id)
            site_hash[:location_obfuscated] = fresh_site.location_obfuscated
            site_hash[:custom_latitude] = fresh_site.latitude
            site_hash[:custom_longitude] = fresh_site.longitude

            [site, site_hash]
        },
        controller: :sites,
        action: :filter,
        defaults: {
            order_by: :name,
            direction: :asc
        },
        valid_associations: [
            {
                join: Arel::Table.new(:projects_sites),
                on: Site.arel_table[:id].eq(Arel::Table.new(:projects_sites)[:site_id]),
                available: false,
                associations: [
                    {
                        join: Project,
                        on: Arel::Table.new(:projects_sites)[:project_id].eq(Project.arel_table[:id]),
                        available: true
                    }
                ]

            },
            {
                join: AudioRecording,
                on: AudioRecording.arel_table[:site_id].eq(Site.arel_table[:id]),
                available: true
            },
        ]
    }
  end

  def set_rails_tz
    tzInfo_id = TimeZoneHelper.to_identifier(self.tzinfo_tz)
    rails_tz_string = TimeZoneHelper.tzinfo_to_ruby(tzInfo_id)
    unless rails_tz_string.blank?
      self.rails_tz = rails_tz_string
    end
  end

end