# frozen_string_literal: true

# == Schema Information
#
# Table name: sites
#
#  id                   :integer          not null, primary key
#  custom_obfuscated_location :boolean          default(FALSE), not null
#  deleted_at           :datetime
#  description          :text
#  image_content_type   :string
#  image_file_name      :string
#  image_file_size      :bigint
#  image_updated_at     :datetime
#  latitude             :decimal(9, 6)
#  longitude            :decimal(9, 6)
#  name                 :string           not null
#  notes                :text
#  obfuscated_latitude  :decimal(9, 6)
#  obfuscated_longitude :decimal(9, 6)
#  rails_tz             :string(255)
#  tzinfo_tz            :string(255)
#  created_at           :datetime
#  updated_at           :datetime
#  creator_id           :integer          not null
#  deleter_id           :integer
#  region_id            :integer
#  updater_id           :integer
#
# Indexes
#
#  index_sites_on_creator_id            (creator_id)
#  index_sites_on_deleter_id            (deleter_id)
#  index_sites_on_obfuscated_latitude   (obfuscated_latitude)
#  index_sites_on_obfuscated_longitude  (obfuscated_longitude)
#  index_sites_on_updater_id            (updater_id)
#
# Foreign Keys
#
#  fk_rails_...         (region_id => regions.id) ON DELETE => cascade
#  sites_creator_id_fk  (creator_id => users.id)
#  sites_deleter_id_fk  (deleter_id => users.id)
#  sites_updater_id_fk  (updater_id => users.id)
#
class Site < ApplicationRecord
  # ensures timezones are handled consistently
  include TimeZoneAttribute

  # relations
  has_many :projects_sites, dependent: :destroy, inverse_of: :site
  has_many :projects, -> { distinct }, through: :projects_sites

  has_many :audio_recordings, inverse_of: :site, dependent: :destroy

  belongs_to :region, inverse_of: :sites, optional: true

  belongs_to :creator, class_name: 'User', inverse_of: :created_sites
  belongs_to :updater, class_name: 'User', inverse_of: :updated_sites, optional: true
  belongs_to :deleter, class_name: 'User', inverse_of: :deleted_sites, optional: true

  has_attached_file :image,
    styles: {
      span4: '300x300#',
      span3: '220x220#',
      span2: '140x140#',
      span1: '60x60#',
      spanhalf: '30x30#'
    },
    default_url: '/images/site/site_:style.png'

  LATITUDE_MIN = -90
  LATITUDE_MAX = 90
  LONGITUDE_MIN = -180
  LONGITUDE_MAX = 180

  # See https://en.wikipedia.org/wiki/Decimal_degrees
  # (neighborhood, street, about 333m)
  JITTER_RANGE = 0.003
  # Don't allow jitter within 10% of the jitter range. Expressed as unit interval.
  JITTER_EXCLUSION = 0.1
  # Don't allow values that are too close to the original location
  JITTER_EXCLUSION_RANGE = JITTER_RANGE * JITTER_EXCLUSION

  # add deleted_at and deleter_id
  acts_as_discardable
  also_discards :audio_recordings, batch: true

  # Automatically update obfuscated coordinates when location changes
  # but only if the obfuscated location was system-generated (not user-provided)
  before_validation :update_obfuscated_location, if: :should_update_obfuscated_location?

  # association validations
  #validates_associated :creator

  # attribute validations
  validates :name, presence: true, length: { minimum: 2 }

  # between -90 and 90 degrees
  validates :latitude, numericality: {
    only_integer: false,
    greater_than_or_equal_to: Site::LATITUDE_MIN,
    less_than_or_equal_to: Site::LATITUDE_MAX,
    message: "%<value>s must be greater than or equal to #{Site::LATITUDE_MIN} and less than or equal to #{Site::LATITUDE_MAX}"
  }, allow_nil: true

  # -180 and 180 degrees
  validates :longitude, numericality: {
    only_integer: false,
    greater_than_or_equal_to: Site::LONGITUDE_MIN,
    less_than_or_equal_to: Site::LONGITUDE_MAX,
    message: "%<value>s must be greater than or equal to #{Site::LONGITUDE_MIN} and less than or equal to #{Site::LONGITUDE_MAX}"
  }, allow_nil: true

  validates_attachment_content_type :image,
    content_type: %r{^image/(jpg|jpeg|pjpeg|png|x-png|gif)$},
    message: 'file type %<value>s is not allowed (only jpeg/png/gif images)'

  # AT 2024: soft deprecating sites existing in more than one project
  # Causes many issues and is officially replaced by the project-region-site relationship
  # Later work will remove the projects_sites join table.
  # Can't enforce this for updates because it would prevent any update for
  # sites that are currently in more than one project.
  validate :only_one_site_per_project, on: :create

  # commonly used queries
  #scope :specified_sites, lambda { |site_ids| where('id in (:ids)', { :ids => site_ids } ) }
  #scope :sites_in_project, lambda { |project_ids| where(Project.specified_projects, { :ids => project_ids } ) }
  #scope :site_projects, lambda{ |project_ids| includes(:projects).where(:projects => {:id => project_ids} ) }

  SAFE_NAME_REGEX = /[^A-Za-z0-9_]+/

  # get's a file system safe ([-A-Za-z0-9_]) version of the site name
  # @return [String]
  def safe_name
    name
      .gsub("'", '')
      .gsub(SAFE_NAME_REGEX, '-')
      .delete_prefix('-')
      .delete_suffix('-')
  end

  # get's a file system safe ([-A-Za-z0-9_]) version of the site name
  # but is calculated on the database server as part of the query.
  # Mirrors the logic in `safe_name`.
  SAFE_NAME_AREL = Site
    .arel_table[:name]
    .replace("'", '')
    .replace(SAFE_NAME_REGEX, '-')
    .trim('-')
    .freeze

  # The same as `safe_name` but appends site.id to ensure a unique name
  # @return [String]
  def unique_safe_name
    "#{safe_name}_#{id}"
  end

  def self.project_ids_arel
    ps = ProjectsSite.arel_table
    s = Site.arel_table

    ps.project(ps[:project_id].array_agg).where(ps[:site_id].eq(s[:id]))
  end

  def get_bookmark
    Bookmark.where(audio_recording: audio_recordings).order(:updated_at).first
  end

  def most_recent_recording
    audio_recordings.order(recorded_date: :desc).first
  end

  def get_bookmark_or_recording
    bookmark = get_bookmark
    recording = most_recent_recording
    if bookmark.present?
      {
        audio_recording: bookmark.audio_recording,
        start_offset_seconds: bookmark.offset_seconds,
        source: :bookmark
      }
    elsif recording.present?
      {
        audio_recording: recording,
        start_offset_seconds: nil,
        source: :audio_recording
      }
    end
  end

  renders_markdown_for :description

  # Replaces `custom_latitude`. Returns obfuscated latitude if location is obfuscated.
  def public_latitude
    if location_obfuscated
      obfuscated_latitude
    else
      latitude
    end
  end

  # Replaces `custom_longitude`. Returns obfuscated longitude if location is obfuscated.
  def public_longitude
    if location_obfuscated
      obfuscated_longitude
    else
      longitude
    end
  end

  # This method is a little funny.
  # If `location_obfuscated` was returned in a query, then that value is used.
  # Otherwise, the obfuscation is calculated with another query.
  def location_obfuscated
    return self['location_obfuscated'] if has_attribute?('location_obfuscated')

    return true if Current.user.nil?

    return false if Current.user.admin?

    # if no associated projects, we can't determine permissions, so obfuscate
    return true if projects.empty?

    is_owner = Access::Core.can_any?(Current.user, Access::Permission::OWNER, projects)

    # obfuscate if level is less than owner
    !is_owner
  end

  def location_jitter_seed
    # random numbers for jitters will be stable for given coordinates
    # but changing coordinates will change the jitter
    # We combine latitude, longitude, and name hash to produce a unique seed.
    # There may be overlap, but the db stores location to 9 digits (6 after decimal)
    # so my spreading out over magnitudes of 9 should reduce collisions greatly.
    # Using site name ensures uniqueness even for identical coordinates.
    (((latitude || 0) * 1e18) + ((longitude || 0) * 1e9) + name.hash).to_i
  end

  def self.add_location_jitter(value, min, max, seed)
    return nil if value.nil?

    raise ArgumentError, 'Seed must be an integer' unless seed.is_a?(Integer)

    # create a stable jitter by using the given seed
    # but ensure a different seed is used for lat/long by incorporating the max
    generator = Random.new(seed * max)

    # sample once
    random = generator.rand

    # partition random over 0.5 to get a range of [-0.5, 0.5]
    # this allows us to spread either side of the target value
    random -= 0.5

    # calculate the actual jitter
    jitter = Site::JITTER_RANGE * random

    # add in an exclusion buffer
    # the addition pushes the jitter away from the mid point
    # we push out by 10% of the jitter range, so for 0.003° ≈ 333m the push range is +- 33m
    jitter += ((jitter >= 0 ? 1 : -1) * (Site::JITTER_RANGE * 0.1))

    # finally augment the input value
    # rounding just to produce a neat value
    modified_value = (value + jitter).round(5)

    # ensure modified value stays within lat/long valid ranges
    modified_value = max if modified_value > max
    modified_value = min if modified_value < min

    modified_value
  end

  # For use in batch queries that may need to obfuscate location on a per row basis.
  # This function assumes you have the effective permissions CTE available
  # somewhere in your query.
  def self.should_return_obfuscated_location_arel(should_obfuscate: nil)
    return Arel::Nodes::SqlLiteral.new('FALSE') if should_obfuscate == false
    return Arel::Nodes::SqlLiteral.new('TRUE') if should_obfuscate == true

    # should hide location: is permission level < :owner?
    Access::EffectivePermission.build_maximum_level_predicate(Access::Permission::OWNER)
  end

  def self.latitude_arel(should_obfuscate: nil)
    return arel_table[:latitude] if should_obfuscate == false
    return arel_table[:obfuscated_latitude] if should_obfuscate == true

    Arel::Nodes::Case.new
      .when(should_return_obfuscated_location_arel)
      .then(arel_table[:obfuscated_latitude])
      .else(arel_table[:latitude])
  end

  def self.longitude_arel(should_obfuscate: nil)
    return arel_table[:longitude] if should_obfuscate == false
    return arel_table[:obfuscated_longitude] if should_obfuscate == true

    Arel::Nodes::Case.new
      .when(should_return_obfuscated_location_arel)
      .then(arel_table[:obfuscated_longitude])
      .else(arel_table[:longitude])
  end

  def only_one_site_per_project
    return if project_ids.one?

    errors.add(:project_ids, 'Site must belong to exactly one project')
  end

  # Updates the obfuscated coordinates based on current latitude/longitude
  def update_obfuscated_location
    raise 'Cannot generate obfuscated coordinates if custom_obfuscated_location is true' if custom_obfuscated_location

    self.obfuscated_latitude = Site.add_location_jitter(
      latitude, Site::LATITUDE_MIN, Site::LATITUDE_MAX, location_jitter_seed
    )

    self.obfuscated_longitude = Site.add_location_jitter(
      longitude, Site::LONGITUDE_MIN, Site::LONGITUDE_MAX, location_jitter_seed
    )
  end

  private

  # Determines if the obfuscated location should be auto-updated
  # Only update if:
  # - The obfuscated location is system-generated (not user-provided), AND
  # - Either latitude or longitude has changed (for existing records)
  def should_update_obfuscated_location?
    # Never auto-update if custom obfuscation is enabled
    return false if custom_obfuscated_location

    # For new records, always generate if not using custom obfuscation
    return true if new_record?

    # For existing records, only update if coordinates changed
    latitude_changed? || longitude_changed?
  end

  # Define filter api settings
  # @param opts [Hash] options for filter settings
  # @option opts [Boolean, nil] :should_obfuscate - if true, latitude/longitude will always be obfuscated.
  #   If false, latitude/longitude will never be obfuscated. If nil, obfuscation depends on user permissions.
  # @return [Hash] filter settings
  def self.filter_settings(**opts)
    should_obfuscate = opts.fetch(:should_obfuscate, nil)

    {
      valid_fields: [:id, :name, :description, :notes, :creator_id,
                     :created_at, :updater_id, :updated_at, :deleter_id, :deleted_at, :region_id,
                     :custom_latitude, :custom_longitude, :longitude, :latitude, :location_obfuscated,
                     :obfuscated_latitude, :obfuscated_longitude, :custom_obfuscated_location],
      render_fields: [:id, :name, :description, :notes, :creator_id,
                      :created_at, :updater_id, :updated_at, :deleter_id, :deleted_at,
                      :region_id,
                      :custom_latitude, :custom_longitude, :longitude, :latitude, :location_obfuscated,
                      :obfuscated_latitude, :obfuscated_longitude, :custom_obfuscated_location],
      text_fields: [:description, :name],
      custom_fields: lambda { |item, _user|
                       # item can be nil or a new record
                       is_new_record = item.nil? || item.new_record?
                       fresh_site = is_new_record ? nil : Site.find(item.id)
                       site_hash = {}

                       unless fresh_site.nil?
                         site_hash = {
                           project_ids: fresh_site.projects.pluck(:id).flatten,
                           timezone_information: fresh_site.timezone,
                           image_urls: Api::Image.image_urls(fresh_site.image),
                           **item.render_markdown_for_api_for(:description)
                         }
                       end

                       [item, site_hash]
                     },
      custom_fields2: {
        # latitude and longitude return obfuscated values for non-owners
        # custom_latitude and custom_longitude are kept for backwards compatibility
        latitude: {
          query_attributes: [],
          transform: nil,
          arel: latitude_arel(should_obfuscate:),
          type: :decimal
        },
        longitude: {
          query_attributes: [],
          transform: nil,
          arel: longitude_arel(should_obfuscate:),
          type: :decimal
        },
        custom_latitude: {
          query_attributes: [],
          transform: nil,
          arel: latitude_arel(should_obfuscate:),
          type: :decimal
        },
        custom_longitude: {
          query_attributes: [],
          transform: nil,
          arel: longitude_arel(should_obfuscate:),
          type: :decimal
        },
        location_obfuscated: {
          query_attributes: [],
          transform: nil,
          arel: should_return_obfuscated_location_arel(should_obfuscate:),
          type: :boolean
        },
        obfuscated_latitude: {
          query_attributes: [],
          transform: nil,
          arel: Site.arel_table[:obfuscated_latitude],
          type: :decimal,
          render: lambda { |item, _user, _effective_projection|
            # only render obfuscated coordinates for owner users
            !item.location_obfuscated
          }
        },
        obfuscated_longitude: {
          query_attributes: [],
          transform: nil,
          arel: Site.arel_table[:obfuscated_longitude],
          type: :decimal,
          render: lambda { |item, _user, _effective_projection|
            # only render obfuscated coordinates for owner users
            !item.location_obfuscated
          }
        },
        custom_obfuscated_location: {
          query_attributes: [],
          transform: nil,
          arel: Site.arel_table[:custom_obfuscated_location],
          type: :boolean,
          render: lambda { |item, _user, _effective_projection|
            # only render for owner users
            !item.location_obfuscated
          }
        }
      },
      new_spec_fields: lambda { |user| # rubocop:disable Lint/UnusedBlockArgument
                         {
                           longitude: nil,
                           latitude: nil,
                           notes: nil,
                           image: nil,
                           tzinfo_tz: nil,
                           rails_tz: nil
                         }
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
          join: Region,
          on: Site.arel_table[:region_id].eq(Region.arel_table[:id]),
          available: true
        },
        {
          join: AudioRecording,
          on: AudioRecording.arel_table[:site_id].eq(Site.arel_table[:id]),
          available: true
        }
      ]
    }
  end

  def self.schema
    {
      type: 'object',
      additionalProperties: false,
      properties: {
        id: { '$ref' => '#/components/schemas/id', readOnly: true },
        name: { type: 'string' },
        **Api::Schema.rendered_markdown(:description),
        **Api::Schema.all_user_stamps,
        #notes: { type: 'object' }, # TODO: https://github.com/QutEcoacoustics/baw-server/issues/467
        notes: { type: 'string' },
        project_ids: { type: 'array', items: { '$ref' => '#/components/schemas/id' } },
        location_obfuscated: { type: 'boolean' },
        # latitude/longitude are aliases for custom_latitude/custom_longitude
        latitude: { type: ['number', 'null'], minimum: -90, maximum: 90 },
        longitude: { type: ['number', 'null'], minimum: -180, maximum: 180 },
        custom_latitude: { type: ['number', 'null'], minimum: -90, maximum: 90, deprecated: true, read_only: true },
        custom_longitude: { type: ['number', 'null'], minimum: -180, maximum: 180, deprecated: true, read_only: true },
        obfuscated_latitude: { type: ['number', 'null'], minimum: -90, maximum: 90, readOnly: false },
        obfuscated_longitude: { type: ['number', 'null'], minimum: -180, maximum: 180, readOnly: false },
        custom_obfuscated_location: { type: 'boolean' },
        timezone_information: Api::Schema.timezone_information,
        image_urls: Api::Schema.image_urls,
        region_id: Api::Schema.id(nullable: true)
      },
      required: [
        :id, :name, :description, :description_html, :description_html_tagline,
        :creator_id, :created_at, :updater_id, :updated_at, :deleter_id,
        :deleted_at, :notes, :project_ids, :location_obfuscated, :latitude,
        :longitude, :timezone_information, :image_urls, :region_id
      ]
    }.freeze
  end
end
