# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_recordings
#
#  id                  :integer          not null, primary key
#  bit_rate_bps        :integer
#  channels            :integer
#  data_length_bytes   :bigint           not null
#  deleted_at          :datetime
#  duration_seconds    :decimal(10, 4)   not null
#  file_hash           :string(524)      not null
#  media_type          :string           not null
#  notes               :text
#  original_file_name  :string
#  recorded_date       :datetime         not null
#  recorded_utc_offset :string(20)
#  sample_rate_hertz   :integer
#  status              :string           default("new")
#  uuid                :string(36)       not null
#  created_at          :datetime
#  updated_at          :datetime
#  creator_id          :integer          not null
#  deleter_id          :integer
#  site_id             :integer          not null
#  updater_id          :integer
#  uploader_id         :integer          not null
#
# Indexes
#
#  audio_recordings_created_updated_at      (created_at,updated_at)
#  audio_recordings_icase_file_hash_id_idx  (lower((file_hash)::text), id)
#  audio_recordings_icase_file_hash_idx     (lower((file_hash)::text))
#  audio_recordings_icase_uuid_id_idx       (lower((uuid)::text), id)
#  audio_recordings_icase_uuid_idx          (lower((uuid)::text))
#  audio_recordings_uuid_uidx               (uuid) UNIQUE
#  index_audio_recordings_on_creator_id     (creator_id)
#  index_audio_recordings_on_deleter_id     (deleter_id)
#  index_audio_recordings_on_site_id        (site_id)
#  index_audio_recordings_on_updater_id     (updater_id)
#  index_audio_recordings_on_uploader_id    (uploader_id)
#
# Foreign Keys
#
#  audio_recordings_creator_id_fk   (creator_id => users.id)
#  audio_recordings_deleter_id_fk   (deleter_id => users.id)
#  audio_recordings_site_id_fk      (site_id => sites.id) ON DELETE => cascade
#  audio_recordings_updater_id_fk   (updater_id => users.id)
#  audio_recordings_uploader_id_fk  (uploader_id => users.id)
#
require 'digest'
require 'digest/md5'

class AudioRecording < ApplicationRecord
  extend Enumerize
  extend AudioRecording::ArelExpressions

  attr_reader :overlapping

  # relations
  belongs_to :site, inverse_of: :audio_recordings
  has_many :audio_events, inverse_of: :audio_recording
  has_many :analysis_jobs_items, inverse_of: :audio_recording
  has_many :bookmarks, inverse_of: :audio_recording
  has_many :tags, through: :audio_events
  has_many :dataset_items, inverse_of: :audio_recording

  has_one :statistics, class_name: Statistics::AudioRecordingStatistics.name, dependent: :destroy
  has_one :harvest_item, inverse_of: :audio_recording, dependent: :destroy

  belongs_to :creator, class_name: 'User', inverse_of: :created_audio_recordings
  belongs_to :updater, class_name: 'User', inverse_of: :updated_audio_recordings,
    optional: true
  belongs_to :deleter, class_name: 'User', inverse_of: :deleted_audio_recordings,
    optional: true
  belongs_to :uploader, class_name: 'User', inverse_of: :uploaded_audio_recordings

  accepts_nested_attributes_for :site

  # add deleted_at and deleter_id
  acts_as_discardable
  also_discards :audio_events

  # Enums for audio recording status
  # new - record created and passes validation
  STATUS_NEW = :new
  # uploading - file being copied from source to dest
  STATUS_UPLOADING = :uploading
  # to_check - uploading is complete - file hash should be compared to hash stored in db
  # ready - audio recording all ready for use on website
  STATUS_READY = :ready
  # corrupt - file hash check failed, audio recording will not be available
  # aborted - a problem occurred during harvesting or checking, the file needs to be harvested again
  STATUS_ABORTED = :aborted

  AVAILABLE_STATUSES_SYMBOLS = [STATUS_NEW, STATUS_UPLOADING, :to_check, STATUS_READY, :corrupt, :aborted].freeze
  AVAILABLE_STATUSES = AVAILABLE_STATUSES_SYMBOLS.map(&:to_s)
  enumerize :status, in: AVAILABLE_STATUSES, predicates: true

  # The token that separates the hash protocol from the hash value.
  # Do not change unless updating all records in the DB!
  HASH_TOKEN = '::'

  # TODO: clean notes column in db
  serialize :notes, coder: JsonTextSerializer

  # association validations
  # AT: disabled... we don't really want to check those models are valid
  #   I'm pretty sure the intention was to validate the association was set.
  #   The actual result here is a lot of "x is invalid" messages when associated
  #   records fail validation even when they haven't been modified.
  #validates_associated :site
  #validates_associated :uploader
  #validates_associated :creator

  # attribute validations
  validates :status, inclusion: { in: AVAILABLE_STATUSES }, presence: true
  validates :uuid, presence: true, length: { is: 36 }, uniqueness: { case_sensitive: false }
  validates :recorded_date, presence: true, timeliness: { on_or_before: -> { Time.zone.now }, type: :datetime }
  validates :duration_seconds, presence: true,
    numericality: { greater_than_or_equal_to: Settings.audio_recording_min_duration_sec }
  validates :sample_rate_hertz, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # the channels field encodes our special version of a bit flag. 0 (no bits flipped) represents
  # a mix down option - we don't store mix downs (if we did they would be stored as single channel / mono (value = 1))
  validates :channels, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :bit_rate_bps, numericality: { only_integer: true, greater_than: 0 }
  validates :media_type, presence: true
  validates :data_length_bytes, presence: true, numericality: { only_integer: true, greater_than: 0 }
  # file hash validations
  # on create, ensure present, case insensitive unique, starts with 'SHA256::', and exactly 72 chars
  validates :file_hash, presence: true, uniqueness: { case_sensitive: false }, length: { is: 72 },
    format: { with: /\ASHA256#{HASH_TOKEN}.{64}\z/, message: "must start with \"SHA256#{HASH_TOKEN}\" with 64 char hash" },
    on: :create
  # on update would usually be the same, but for the audio check this needs to ignore
  validates :file_hash, presence: true, uniqueness: { case_sensitive: false }, length: { is: 72 },
    format: { with: /\ASHA256#{HASH_TOKEN}.{64}\z/, message: "must start with \"SHA256#{HASH_TOKEN}\" with 64 char hash" },
    on: :update, unless: :missing_hash_value?

  after_initialize :set_uuid

  # postgres-specific
  scope :start_after, ->(time) { where(recorded_date: time..) }
  scope :start_before, ->(time) { where(recorded_date: ..time) }
  scope :start_before_not_equal, ->(time) { where(recorded_date: ...time) }
  scope :end_after, ->(time) { where('recorded_date + CAST(duration_seconds || \' seconds\' as interval)  >= ?', time) }
  scope(:end_after_not_equal, lambda { |time|
                                where('recorded_date + CAST(duration_seconds || \' seconds\' as interval)  > ?', time)
                              })
  scope(:end_before, lambda { |time|
                       where('recorded_date + CAST(duration_seconds || \'seconds\' as interval) <= ?', time)
                     })
  scope :has_tag, ->(tag) { includes(:tags).where(tags: { text: tag }) }
  scope :has_tags, ->(tags) { includes(:tags).where('tags.text IN ?', tags) }
  scope :does_not_have_tag, ->(tag) { includes(:tags).where.not(tags: { text: tag }) }
  scope :does_not_have_tags, ->(tags) { includes(:tags).where('tags.text NOT IN ?', tags) }
  scope(:tag_count, lambda { |num_tags|
                      #   'audio_events_tags.tag_id' => Tagging.select(:tag_id).group(:tag_id).having('count(tag_id) > ?', num_tags))

                      tagging_arel = Tagging.arel_table
                      grouping = tagging_arel
                        .project(tagging_arel[:tag_id])
                        .group(tagging_arel[:tag_id])
                        .having(tagging_arel[:tag_id].count.gt(num_tags.to_i))

                      audio_events_arel = AudioEvent.arel_table
                      condition = audio_events_arel[:tag_id].in(grouping)

                      includes(:tags).where(condition)
                    })
  scope(:tag_types, lambda { |tag_types|
                      tags_arel = Tag.arel_table
                      condition = tags_arel[:type_of_tag].in(tag_types)
                      includes(:tags).where(condition)
                    })
  scope(:tag_text, lambda { |tag_text|
                     sanitized_value = tag_text.gsub(/[\\_%|]/) { |x| "\\#{x}" }
                     contains_value = "#{sanitized_value}%"
                     includes(:tags).where(Tag.arel_table[:text].matches(contains_value))
                   })
  scope(:order_by_absolute_end_desc, lambda {
                                       order('recorded_date + CAST(duration_seconds || \' seconds\' as interval) DESC')
                                     })
  scope :total_data_bytes, -> { sum(arel_table[:data_length_bytes].cast('bigint')) }
  scope :total_duration_seconds, -> { sum(arel_table[:duration_seconds].cast('bigint')) }

  # Allows this model to infer its timezone when included with larger queries
  # constructed by filter args.
  def self.with_timezone
    {
      model: Site,
      association: :site,
      column: :tzinfo_tz
    }
  end

  # Check if the original file for this audio recording currently exists.
  def original_file_exists?
    !original_file_paths.empty?
  end

  # Get the existing paths for the audio recording file.
  def original_file_paths
    modify_parameters = {
      uuid:,
      datetime_with_offset: recorded_date,
      original_format: original_format_calculated
    }

    audio_original = BawWorkers::Config.original_audio_helper

    audio_original.existing_paths(modify_parameters)
  end

  # gets the 'ideal' file name (not path) for an audio recording that is stored on disk
  def canonical_filename
    modify_parameters = {
      uuid:,
      original_format: original_format_calculated
    }

    audio_original = BawWorkers::Config.original_audio_helper
    audio_original.file_name_uuid(modify_parameters)
  end

  # gets a filename that looks nice enough to provide to a user for a file download
  def friendly_name
    return nil if site.nil?

    name = site.safe_name
    name = 'NONAME' if name.blank?

    # use Z if possible, or as a backup for a missing zone
    if site.timezone.blank? || site.timezone[:utc_total_offset].zero?
      recorded_date&.utc&.strftime('%Y%m%dT%H%M%SZ')
    else
      timezone = TimeZoneHelper.tzinfo_class(site.tzinfo_tz)
      recorded_date.in_time_zone(timezone).strftime('%Y%m%dT%H%M%S%z')
    end => date

    "#{date}_#{name}_#{id}.#{original_format_calculated}"
  end

  # gets a filename that looks nice enough to provide to a user for a file download
  # but is calculated on the database server as part of the query.
  # Mirrors the logic in `friendly_name`.
  FRIENDLY_NAME_AREL = build_friendly_name_query.freeze

  FRIENDLY_NAME_REGEX = /(?<date>\d{8}T\d{6}(?:Z|[+-]\d+))_(?<site_name>[-\w]+)_(?<id>\d+)\.(?<extension>.+)/

  # Calculate the format of original audio recording.
  # Despite the weird name this returns an extension!
  def original_format_calculated
    # this method previously determined format based on `original_file_name` but this approach is erroneous;
    # Our source of truth should be the `media_type` field. The `original_file_name` is kept as metadata only.
    # In practice, there is no difference currently but later when transcoding harvested audio is enabled,
    # these formats will not agree.
    Mime::Type.file_extension_of(media_type)
  end

  # check for and correct any overlaps.
  # this method runs validations.
  # this method depends on a number of attributes being valid.
  # @return [Boolean, Hash] false if not valid, otherwise hash of overlap info
  def fix_overlaps
    # only run if the record is valid
    return false if invalid?

    max_overlap_sec = Settings.audio_recording_max_overlap_sec

    # correct any overlaps
    AudioRecordingOverlap.fix(self, max_overlap_sec)
  end

  def self.build_by_file_hash(recording_params)
    match = AudioRecording.where(
      original_file_name: recording_params[:original_file_name],
      file_hash: recording_params[:file_hash],
      recorded_date: Time.zone.parse(recording_params[:recorded_date]).utc,
      data_length_bytes: recording_params[:data_length_bytes],
      media_type: recording_params[:media_type],
      duration_seconds: recording_params[:duration_seconds].round(4),
      site_id: recording_params[:site_id],
      status: 'aborted'
    )

    if match.count == 1
      found = match.first
      found.status = 'new'

      # set other attributes which may not have been included
      # when the previous create request failed
      found.sample_rate_hertz = recording_params[:sample_rate_hertz].to_i
      found.channels = recording_params[:channels].to_i
      found.bit_rate_bps = recording_params[:bit_rate_bps].to_i
      found.notes = recording_params[:notes]

      found
    else
      # this endpoint is reasonably secure and we're quite reliant on it just working!
      recording_params.permit!
      AudioRecording.new(recording_params)
    end
  end

  def self.check_storage
    audio_original = BawWorkers::Config.original_audio_helper
    existing_dirs = audio_original.existing_dirs

    if existing_dirs.empty?
      msg = 'No audio recording storage directories are available.'
      logger.warn msg
      { message: msg, success: false }
    else
      msg = "#{existing_dirs.size} audio recording storage #{existing_dirs.size == 1 ? 'directory' : 'directories'} available."
      { message: msg, success: true }
    end
  end

  # Define filter api settings
  def self.filter_settings
    {
      valid_fields: [
        :id, :uuid, :recorded_date, :site_id,
        :duration_seconds,
        :sample_rate_hertz, :channels, :bit_rate_bps, :media_type,
        :data_length_bytes, :status, :created_at, :updated_at,
        :recorded_end_date, :file_hash, :uploader_id, :original_file_name, :recorded_utc_offset

        #, :notes, :creator_id,
        #:updater_id, :deleter_id, :deleted_at,
      ],
      render_fields: [:id, :uuid, :recorded_date, :site_id,
                      :duration_seconds,
                      :sample_rate_hertz, :channels, :bit_rate_bps, :media_type,
                      :data_length_bytes, :status, :created_at, :creator_id,
                      :deleted_at, :deleter_id, :updated_at, :updater_id,
                      :notes, :file_hash, :uploader_id, :original_file_name,
                      :canonical_file_name, :recorded_date_timezone, :recorded_utc_offset],
      text_fields: [:media_type, :status, :original_file_name],
      custom_fields: lambda { |item, _user|
                       [item, {}]
                     },
      # a better designed custom field
      # can be included in a projection!
      # dirty hack: but there's not much point innovating here - the whole mess
      # needs a rewrite.
      custom_fields2: {
        canonical_file_name: {
          query_attributes: [:id, :site_id, :recorded_date, :media_type],
          transform: ->(item) { item&.friendly_name },
          arel: nil,
          type: :string
        },
        recorded_date_timezone: {
          query_attributes: [],
          transform: nil,
          arel: arel_timezone,
          type: :string
        },
        recorded_end_date: {
          query_attributes: [],
          transform: nil,
          arel: arel_recorded_end_date,
          type: :datetime
        }
      },
      new_spec_fields: lambda { |_user|
                         {
                           site_id: nil,
                           uploader_id: nil,
                           sample_rate_hertz: nil,
                           media_type: nil,
                           recorded_date: nil,
                           bit_rate_bps: nil,
                           data_length_bytes: nil,
                           channels: nil,
                           duration_seconds: nil,
                           file_hash: nil,
                           original_file_name: nil
                         }
                       },
      controller: :audio_recordings,
      action: :filter,
      defaults: {
        order_by: :recorded_date,
        direction: :desc
      },
      capabilities: {
        original_download: {
          #can_list: ->(klass) { Current.ability.can?(:original, klass) },
          can_item: ->(item) { Current.ability.can?(:original, item) },
          details: lambda { |can, _item, _klass|
                     unless can
                       'You do not have permission to download the original audio recording. Check your access level or the original download settings for this project'
                     end
                   }
        }
      },
      valid_associations: [
        {
          join: AudioEvent,
          on: AudioRecording.arel_table[:id].eq(AudioEvent.arel_table[:audio_recording_id]),
          available: true,
          associations: [
            {
              join: Tagging,
              on: AudioEvent.arel_table[:id].eq(Tagging.arel_table[:audio_event_id]),
              available: true,
              associations: [
                {
                  join: Tag,
                  on: Tagging.arel_table[:tag_id].eq(Tag.arel_table[:id]),
                  available: true
                }
              ]

            }
          ]
        },
        {
          join: Site,
          on: AudioRecording.arel_table[:site_id].eq(Site.arel_table[:id]),
          available: true,
          associations: [
            {
              join: Region,
              on: Site.arel_table[:region_id].eq(Region.arel_table[:id]),
              available: true
            },
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

            }
          ]
        },
        {
          join: Bookmark,
          on: AudioRecording.arel_table[:id].eq(Bookmark.arel_table[:audio_recording_id]),
          available: true
        },
        {
          join: HarvestItem,
          on: AudioRecording.arel_table[:id].eq(HarvestItem.arel_table[:audio_recording_id]),
          available: true,
          associations: [
            {
              join: Harvest,
              on: HarvestItem.arel_table[:harvest_id].eq(Harvest.arel_table[:id]),
              available: true
            }
          ]
        }
      ]
    }
  end

  def self.schema
    {
      type: 'object',
      additionalProperties: false,
      properties: {
        id: Api::Schema.id,
        uuid: Api::Schema.uuid,
        site_id: Api::Schema.id,
        duration_seconds: { type: 'number' },
        sample_rate_hertz: { type: 'number' },
        channels: { type: 'number' },
        bit_rate_bps: { type: 'number' },
        media_type: { type: 'string' },
        data_length_bytes: { type: 'number' },
        status: { type: 'string' },
        **Api::Schema.all_user_stamps,
        recorded_date: Api::Schema.date,
        file_hash: { type: 'string' },
        notes: { type: 'object' },
        recorded_date_timezone: { type: ['null', 'string'] },
        uploader_id: Api::Schema.id(nullable: true, read_only: false),
        original_file_name: { type: 'string' },
        canonical_file_name: { type: 'string', readOnly: true },
        recorded_utc_offset: { type: ['null', 'string'], readOnly: true }
      },
      required: [
        :id,
        :uuid,
        :site_id,
        :duration_seconds,
        :sample_rate_hertz,
        :channels,
        :bit_rate_bps,
        :media_type,
        :data_length_bytes,
        :status,
        :creator_id,
        :created_at,
        :updater_id,
        :updated_at,
        :deleter_id,
        :deleted_at,
        :recorded_date,
        :file_hash,
        :notes,
        :uploader_id,
        :original_file_name,
        :canonical_file_name,
        :recorded_utc_offset
      ]
    }.freeze
  end

  def set_uuid
    # only set uuid if uuid attribute is available, is blank, and this is a new object
    self.uuid = UUIDTools::UUID.random_create.to_s if has_attribute?(:uuid) && uuid.blank? && new_record?
  end

  # Splits the file hash into an array with two values. The first value is the hash type, the second is the hash value.
  # @return string[] - Of length 2. First value is hash protocol. Second value is hash value.
  def split_file_hash
    result = file_hash.split(HASH_TOKEN)
    raise "Invalid file hash detected (more than one \"#{HASH_TOKEN}\" found)" if result.length != 2

    result
  end

  private

  def missing_hash_value?
    file_hash == "SHA256#{HASH_TOKEN}"
  end

  # Results in:
  # ("audio_recordings"."recorded_date" + CAST("audio_recordings"."duration_seconds" || 'seconds' as interval))
  def self.arel_recorded_end_date
    seconds_as_interval = Arel::Nodes::SqlLiteral.new("' seconds' as interval")
    infix_op_string_join = Arel::Nodes::InfixOperation.new(:'||', AudioRecording.arel_table[:duration_seconds],
      seconds_as_interval)
    function_cast = Arel::Nodes::NamedFunction.new('CAST', [infix_op_string_join])

    # Don't omit the grouping or else we run into order of operation issues in compound expressions
    Arel::Nodes::Grouping.new(
      Arel::Nodes::InfixOperation.new(:+, AudioRecording.arel_table[:recorded_date], function_cast)
    )
  end

  # Results in:
  # ((SELECT tzinfo_tz FROM "sites" WHERE "audio_recordings"."site_id" = "sites"."id"))
  def self.arel_timezone
    site = Site.arel_table
    analysis_job = AudioRecording.arel_table
    Arel.grouping(site.where(analysis_job[:site_id] == site[:id]).project(:tzinfo_tz))
  end
end
