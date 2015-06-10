require 'digest'
require 'digest/md5'

class AudioRecording < ActiveRecord::Base

  extend Enumerize

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  attr_reader :overlapping

  # relations
  belongs_to :site, inverse_of: :audio_recordings
  has_many :audio_events, inverse_of: :audio_recording
  #has_many :analysis_items
  has_many :bookmarks, inverse_of: :audio_recording
  has_many :tags, through: :audio_events

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_audio_recordings
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_audio_recordings
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_audio_recordings
  belongs_to :uploader, class_name: 'User', foreign_key: :uploader_id, inverse_of: :uploaded_audio_recordings

  accepts_nested_attributes_for :site

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # Enums for audio recording status
  # new - record created and passes validation
  # uploading - file being copied from source to dest
  # to_check - uploading is complete - file hash should be compared to hash stored in db
  # ready - audio recording all ready for use on website
  # corrupt - file hash check failed, audio recording will not be available
  # aborted - a problem occurred during harvesting or checking, the file needs to be harvested again
  AVAILABLE_STATUSES_SYMBOLS = [:new, :uploading, :to_check, :ready, :corrupt, :aborted]
  AVAILABLE_STATUSES = AVAILABLE_STATUSES_SYMBOLS.map { |item| item.to_s }
  enumerize :status, in: AVAILABLE_STATUSES, predicates: true

  # association validations
  validates :site, existence: true
  validates :uploader, existence: true
  validates :creator, existence: true

  # attribute validations
  validates :status, inclusion: {in: AVAILABLE_STATUSES}, presence: true
  validates :uuid, presence: true, length: {is: 36}, uniqueness: {case_sensitive: false}
  validates :recorded_date, presence: true, timeliness: {on_or_before: lambda { Time.zone.now }, type: :datetime}
  validates :duration_seconds, presence: true, numericality: {greater_than_or_equal_to: Settings.audio_recording_min_duration_sec}
  validates :sample_rate_hertz, presence: true, numericality: {only_integer: true, greater_than: 0}

  # the channels field encodes our special version of a bit flag. 0 (no bits flipped) represents
  # a mix down option - we don't store mix downs (if we did they would be stored as single channel / mono (value = 1))
  validates :channels, presence: true, numericality: {only_integer: true, greater_than: 0}
  validates :bit_rate_bps, numericality: {only_integer: true, greater_than: 0}
  validates :media_type, presence: true
  validates :data_length_bytes, presence: true, numericality: {only_integer: true, greater_than: 0}
  validates :file_hash, presence: true, uniqueness: {case_sensitive: false}
  validate :check_duplicate_file_hashes, :check_overlapping

  before_validation :set_uuid, on: :create

  # postgres-specific
  scope :start_after, lambda { |time| where('recorded_date >= ?', time) }
  scope :start_before, lambda { |time| where('recorded_date <= ?', time) }
  scope :start_before_not_equal, lambda { |time| where('recorded_date < ?', time) }
  scope :end_after, lambda { |time| where('recorded_date + CAST(duration_seconds || \' seconds\' as interval)  >= ?', time) }
  scope :end_after_not_equal, lambda { |time| where('recorded_date + CAST(duration_seconds || \' seconds\' as interval)  > ?', time) }
  scope :end_before, lambda { |time| where('end_time_seconds + CAST(duration_seconds || \'seconds\' as interval) <= ?', time) }
  scope :has_tag, lambda { |tag| includes(:tags).where('tags.text = ?', tag) }
  scope :has_tags, lambda { |tags| includes(:tags).where('tags.text IN ?', tags) }
  scope :does_not_have_tag, lambda { |tag| includes(:tags).where('tags.text <> ?', tag) }
  scope :does_not_have_tags, lambda { |tags| includes(:tags).where('tags.text NOT IN ?', tags) }
  scope :tag_count, lambda { |num_tags| includes(:tags).where('audio_events_tags.tag_id' => Tagging.select(:tag_id).group(:tag_id).having('count(tag_id) > ?', num_tags)) }
  scope :tag_types, lambda { |tag_types| includes(:tags).where('tags.type_of_tag' => tag_types) }
  scope :tag_text, lambda { |tag_text| includes(:tags).where(Tag.arel_table[:text].matches("%#{tag_text}%")) }

  scope :order_by_absolute_end_desc, lambda { order('recorded_date + CAST(duration_seconds || \' seconds\' as interval) DESC')}

  # Check if the original file for this audio recording currently exists.
  def original_file_exists?
    self.original_file_paths.length > 0
  end

  # Get the existing paths for the audio recording file.
  def original_file_paths
    original_format = '.wv' # pick something

    if !self.original_file_name.blank?
      original_format = File.extname(self.original_file_name)
    elsif !self.media_type.blank?
      original_format = Mime::Type.file_extension_of(self.media_type)
    end

    source_existing_paths = []
    unless original_format.blank?
      modify_parameters = {
          uuid: self.uuid,
          datetime_with_offset: self.recorded_date,
          original_format: self.original_format_calculated
      }

      audio_original = BawWorkers::Settings.original_audio_helper
      source_existing_paths = audio_original.existing_paths(modify_parameters)
    end

    source_existing_paths
  end

  # Calculate the format of original audio recording.
  def original_format_calculated
    if self.original_file_name.blank?
      Mime::Type.lookup(self.media_type).to_sym.to_s
    else
      File.extname(self.original_file_name)
    end
  end

  def check_file_hash
    # ensure this audio recording needs to be checked
    return if self.status != 'to_check'

    # type of hash is at start of hash_to_compare, split using two colons
    hash_type, compare_hash = self.file_hash.split('::')

    # TODO: use BawWorkers to get hash - only allow SHA256.

    case hash_type
      when 'MD5'
        incr_hash = ::Digest::MD5.new
      else
        incr_hash = Digest::SHA256.new
    end

    raise "Audio recording file could not be found: #{self.uuid}" if self.original_file_paths.length < 1

    # assume that all files for a recording are identical. pick the first one
    File.open(self.original_file_paths.first!) do |file|
      buffer = ''

      # Read the file 512 bytes at a time
      until file.eof
        file.read(512, buffer)
        incr_hash.update(buffer)
      end
    end

    # if hashes do not match, mark audio recording as corrupt
    if incr_hash.hexdigest.upcase == compare_hash.upcase
      self.status = 'ready'
      self.save!
      logger.info "Audio recording #{self.uuid} file hash was checked and matched. It is now in 'ready' state."
    else
      self.status = 'corrupt'
      self.save!
      raise "Audio recording file hash did not match stored hash: #{self.uuid} File hash: #{incr_hash.hexdigest.upcase} stored hash: #{compare_hash.upcase}."
    end
  end

  # returns true if this audio_recording can be accessed, otherwise false
  def check_status
    can_be_accessed = false

    case self.status.to_s
      when 'new'
        logger.info "Audio recording #{self.uuid} is in state 'new' and is not yet ready to be accessed."
      when 'to_check'
        logger.info "Audio recording #{self.uuid} is in state 'to_check' and will be checked by comparing the file hash and stored hash."
        self.check_file_hash
      when 'corrupt'
        logger.warn "Audio recording #{self.uuid} is in state 'corrupt' and cannot be accessed."
      when 'ignore'
        logger.info "Audio recording #{self.uuid} is in state 'ignore' and cannot be accessed."
      when 'ready'
        logger.info "Audio recording #{self.uuid} is in state 'ready' and can be accessed."
        can_be_accessed = true
      else
        logger.info "Audio recording #{self.uuid} is in state '#{self.status.to_s}', which is unknown."
    end

    can_be_accessed
  end

  def self.check_storage
    audio_original = BawWorkers::Config.original_audio_helper
    existing_dirs = audio_original.existing_dirs

    if existing_dirs.empty?
      msg = 'No audio recording storage directories are available.'
      logger.warn msg
      {message: msg, success: false}
    else
      msg = "#{existing_dirs.size} audio recording storage #{existing_dirs.size == 1 ? 'directory' : 'directories'} available."
      {message: msg, success: true}
    end
  end

  # Define filter api settings
  def self.filter_settings
    {
        valid_fields: [
            :id, :uuid, :recorded_date, :site_id, :duration_seconds,
            :sample_rate_hertz, :channels, :bit_rate_bps, :media_type,
            :data_length_bytes, :status, :created_at, :updated_at
        # :uploader_id, :file_hash, , :notes, :creator_id,
        #:updater_id, :deleter_id, :deleted_at, :original_file_name
        ],
        render_fields: [:id, :uuid, :recorded_date, :site_id, :duration_seconds,
                        :sample_rate_hertz, :channels, :bit_rate_bps, :media_type,
                        :data_length_bytes, :status, :created_at, :updated_at],
        text_fields: [:media_type, :status],
        controller: :audio_recordings,
        action: :filter,
        defaults: {
            order_by: :recorded_date,
            direction: :desc
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
                        available: false,
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
                available: true
            },
            {
                join: Bookmark,
                on: AudioRecording.arel_table[:id].eq(Bookmark.arel_table[:audio_recording_id]),
                available: true
            }
        ]
    }
  end

  private
  def set_uuid
    self.uuid = UUIDTools::UUID.random_create.to_s
  end

  def check_duplicate_file_hashes

    if self.file_hash == 'SHA256::'
      # short-circuit the invalid hash 'SHA256::'
      # TODO: ignore file_hash of 'SHA256::' for now
      #errors.add(:file_hash, 'is not valid and needs to be updated.')
    else
      # check that no other audio recording has the same file_hash
      query = AudioRecording.where(file_hash: self.file_hash)

      unless self.id.blank?
        query = query.where('id <> ?', self.id)
      end

      count = query.count
      if count > 0
        ids = query.pluck(:id)
        errors.add(:file_hash, "has already been taken by id #{ids}.")
      end

    end
  end

  def check_overlapping

    # validate model first, as this check can occur before attribute validations are run
    AudioRecordingOverlap.validate(self)
    return if errors.count > 0

    overlaps = AudioRecordingOverlap.get(self, Settings.audio_recording_max_overlap_sec)

    if overlaps[:overlap][:items].size > 0
      errors.add(:recorded_date, overlaps[:overlap])
    end

  end

end
