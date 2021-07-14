# frozen_string_literal: true

# == Schema Information
#
# Table name: sites
#
#  id                 :integer          not null, primary key
#  deleted_at         :datetime
#  description        :text
#  image_content_type :string
#  image_file_name    :string
#  image_file_size    :integer
#  image_updated_at   :datetime
#  latitude           :decimal(9, 6)
#  longitude          :decimal(9, 6)
#  name               :string           not null
#  notes              :text
#  rails_tz           :string(255)
#  tzinfo_tz          :string(255)
#  created_at         :datetime
#  updated_at         :datetime
#  creator_id         :integer          not null
#  deleter_id         :integer
#  region_id          :integer
#  updater_id         :integer
#
# Indexes
#
#  index_sites_on_creator_id  (creator_id)
#  index_sites_on_deleter_id  (deleter_id)
#  index_sites_on_updater_id  (updater_id)
#
# Foreign Keys
#
#  fk_rails_...         (region_id => regions.id)
#  sites_creator_id_fk  (creator_id => users.id)
#  sites_deleter_id_fk  (deleter_id => users.id)
#  sites_updater_id_fk  (updater_id => users.id)
#
class Site < ApplicationRecord
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # ensures timezones are handled consistently
  include TimeZoneAttribute

  attr_accessor :custom_latitude, :custom_longitude, :location_obfuscated

  # relations
  has_and_belongs_to_many :projects, -> { distinct }
  has_many :audio_recordings, inverse_of: :site

  belongs_to :region, foreign_key: :region_id, inverse_of: :sites, optional: true

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_sites
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_sites, optional: true
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_sites, optional: true

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
  # (scale of a large town or village)
  JITTER_RANGE = 0.03

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # association validations
  validates_associated :creator

  # attribute validations
  validates :name, presence: true, length: { minimum: 2 }

  # between -90 and 90 degrees
  validates :latitude, numericality: {
    only_integer: false,
    greater_than_or_equal_to: Site::LATITUDE_MIN,
    less_than_or_equal_to: Site::LATITUDE_MAX,
    message: "%{value} must be greater than or equal to #{Site::LATITUDE_MIN} and less than or equal to #{Site::LATITUDE_MAX}"
  }, allow_nil: true

  # -180 and 180 degrees
  validates :longitude, numericality: {
    only_integer: false,
    greater_than_or_equal_to: Site::LONGITUDE_MIN,
    less_than_or_equal_to: Site::LONGITUDE_MAX,
    message: "%{value} must be greater than or equal to #{Site::LONGITUDE_MIN} and less than or equal to #{Site::LONGITUDE_MAX}"
  }, allow_nil: true

  validates_attachment_content_type :image,
                                    content_type: %r{^image/(jpg|jpeg|pjpeg|png|x-png|gif)$},
                                    message: 'file type %{value} is not allowed (only jpeg/png/gif images)'

  # commonly used queries
  #scope :specified_sites, lambda { |site_ids| where('id in (:ids)', { :ids => site_ids } ) }
  #scope :sites_in_project, lambda { |project_ids| where(Project.specified_projects, { :ids => project_ids } ) }
  #scope :site_projects, lambda{ |project_ids| includes(:projects).where(:projects => {:id => project_ids} ) }

  def get_bookmark
    Bookmark.where(audio_recording: audio_recordings).order(:updated_at).first
  end

  def most_recent_recording
    audio_recordings.order(recorded_date: :desc).first
  end

  def get_bookmark_or_recording
    bookmark = get_bookmark
    recording = most_recent_recording
    if !bookmark.blank?
      {
        audio_recording: bookmark.audio_recording,
        start_offset_seconds: bookmark.offset_seconds,
        source: :bookmark
      }
    elsif !recording.blank?
      {
        audio_recording: recording,
        start_offset_seconds: nil,
        source: :audio_recording
      }
    end
  end

  # overrides getting, does not change setting
  def latitude
    value = read_attribute(:latitude)
    if location_obfuscated && !value.blank?
      Site.add_location_jitter(value, Site::LATITUDE_MIN, Site::LATITUDE_MAX)
    else
      value
    end
  end

  # overrides getting, does not change setting
  def longitude
    value = read_attribute(:longitude)
    if location_obfuscated && !value.blank?
      Site.add_location_jitter(value, Site::LONGITUDE_MIN, Site::LONGITUDE_MAX)
    else
      value
    end
  end

  def update_location_obfuscated(current_user)
    if projects.empty?
      @location_obfuscated = true
      return
    end

    Access::Core.check_orphan_site!(self)
    is_owner = Access::Core.can_any?(current_user, :owner, projects)

    # obfuscate if level is less than owner
    @location_obfuscated = !is_owner
  end

  renders_markdown_for :description

  def self.add_location_jitter(value, min, max)
    # multiply by 10,000 to get to ~10m accuracy
    accuracy = 10_000
    multiplied = (value * accuracy).floor.to_i

    # get a range for potential jitter

    max_diff = (Site::JITTER_RANGE * accuracy).floor.to_i
    range_min = multiplied - max_diff
    range_max = multiplied + max_diff

    # included range (inclusive range)
    range = (range_min..range_max).to_a

    excluded_diff = (Site::JITTER_RANGE * 0.1 * accuracy).floor.to_i
    excluded_min = multiplied - excluded_diff
    excluded_max = multiplied + excluded_diff

    # excluded numbers (inclusive range)
    excluded = (excluded_min..excluded_max).to_a

    # create array of available numbers with middle range excluded
    available = range - excluded

    # select a random value from the available array of ints
    selected = available.sample

    # ensure the last digit is not zero (0), as this will be removed when converted
    selected += 1 if selected.to_s.last == '0'

    # round to ensure precision is maintained (damn floating point in-exactness)
    # 3 decimal places is at the scale of an 'individual street, land parcel'
    modified_value = selected.fdiv(accuracy).round(4)

    # ensure range is maintained (damn floating point in-exactness)
    modified_value = value + Site::JITTER_RANGE if modified_value > (value + Site::JITTER_RANGE)
    modified_value = value - Site::JITTER_RANGE if modified_value < (value - Site::JITTER_RANGE)

    # ensure modified value stays within lat/long valid ranges
    modified_value = max if modified_value > max
    modified_value = min if modified_value < min

    modified_value
  end

  # Define filter api settings
  def self.filter_settings
    {
      valid_fields: [:id, :name, :description, :notes, :creator_id,
                     :created_at, :updater_id, :updated_at, :deleter_id, :deleted_at, :region_id],
      render_fields: [:id, :name, :description, :notes, :creator_id,
                      :created_at, :updater_id, :updated_at, :deleter_id, :deleted_at, :region_id],
      text_fields: [:description, :name],
      custom_fields: lambda { |item, user|
                       # item can be nil or a new record
                       is_new_record = item.nil? || item.new_record?
                       fresh_site = is_new_record ? nil : Site.find(item.id)
                       site_hash = {}

                       unless fresh_site.nil?
                         fresh_site.update_location_obfuscated(user)
                         site_hash = {
                           project_ids: fresh_site.projects.pluck(:id).flatten,
                           location_obfuscated: fresh_site.location_obfuscated,
                           custom_latitude: fresh_site.latitude,
                           custom_longitude: fresh_site.longitude,
                           timezone_information: fresh_site.timezone,
                           image_urls: Api::Image.image_urls(fresh_site.image),
                           **item.render_markdown_for_api_for(:description)
                         }
                       end

                       [item, site_hash]
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
        custom_latitude: { type: ['number', 'null'], minimum: -90, maximum: 90 },
        custom_longitude: { type: ['number', 'null'], minimum: -180, maximum: 180 },
        timezone_information: Api::Schema.timezone_information,
        image_urls: Api::Schema.image_urls,
        region_id: { '$ref' => '#/components/schemas/nullableId' }
      },
      required: [
        :id, :name, :description, :description_html, :description_html_tagline,
        :creator_id, :created_at, :updater_id, :updated_at, :deleter_id,
        :deleted_at, :notes, :project_ids, :location_obfuscated, :custom_latitude,
        :custom_longitude, :timezone_information, :image_urls, :region_id
      ]
    }.freeze
  end
end
