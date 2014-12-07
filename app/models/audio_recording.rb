require 'digest'
require 'digest/md5'

class AudioRecording < ActiveRecord::Base

  extend Enumerize

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # attr
  attr_accessible :bit_rate_bps, :channels, :data_length_bytes, :original_file_name,
                  :duration_seconds, :file_hash, :media_type, :notes,
                  :recorded_date, :sample_rate_hertz, :status, :uploader_id,
                  :site_id
  attr_reader :overlapping
  attr_protected :uuid

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
                        :data_length_bytes, :status],
        text_fields: [:media_type, :status],
        controller: :audio_recordings,
        action: :filter,
        defaults: {
            order_by: :recorded_date,
            direction: :desc
        }
    }
  end

  def get_listen_path
    "/listen/#{self.id}"
  end

  private
  def set_uuid
    self.uuid = UUIDTools::UUID.random_create.to_s
  end

  def check_duplicate_file_hashes
    # self.id will be nil; self will not be in database yet
    query = AudioRecording.where(file_hash: self.file_hash)
    unless self.id.blank?
      query = query.where('id <> ?', self.id)
    end
    count = query.count
    if count > 0
      ids = query.select(:id).to_a.map { |item| item.id }
      errors.add(:file_hash, "has already been taken by id #{ids}.")
    end
  end

  def check_overlapping

    # validate model first, as this check can occur before attribute validations are run

    errors.add(:recorded_date, 'must have a value') if self.recorded_date.blank?
    errors.add(:duration_seconds, 'must have a value') if self.duration_seconds.blank?
    errors.add(:site_id, 'must have a value') if self.site_id.blank?
    return if errors.count > 0

    # recordings are overlapping if:
    # do not have the same id,
    # do have same site
    # start is before .recorded_date.advance(seconds: self.duration_seconds)
    # and end is before self.recorded_date
    # self.id will be nil; self will not be in database yet
    if self.recorded_date.respond_to?(:advance)
      end_time = self.recorded_date.advance(seconds: self.duration_seconds)
      query = AudioRecording
      .where(site_id: self.site_id)
      .start_before_not_equal(end_time)
      .end_after_not_equal(self.recorded_date)
      unless self.id.blank?
        query = query.where('id <> ?', self.id)
      end
      count = query.count
      if count > 0

        new_recorded_date = self.recorded_date
        new_end_date = self.recorded_date.advance(seconds: self.duration_seconds)

        overlapping = query.map { |a|

          existing_recorded_data = a.recorded_date
          existing_audio_end = a.recorded_date.advance(seconds: a.duration_seconds)

          if new_recorded_date < existing_recorded_data
            # overlap is at end of new, start of existing
            overlap_amount = new_end_date - existing_recorded_data
            overlap_location = 'start of existing, end of new'
          else
            # overlap is at start of new, end of existing
            overlap_amount = existing_audio_end - new_recorded_date
            overlap_location = 'start of new, end of existing'
          end

          {
              uuid: a.uuid,
              id: a.id,
              recorded_date: a.recorded_date,
              duration: a.duration_seconds,
              end_date: existing_audio_end,
              overlap_amount: overlap_amount,
              overlap_location: overlap_location
          }
        }

        message = {
            problem: 'audio recordings that overlap in the same site (calculated from recording_start and duration_seconds) are not permitted',
            overlapping_audio_recordings: overlapping
        }

        # define overlapping so it can be accessed in the controller
        @overlapping = overlapping

        # add errors entry to this model instance to record overlap problems
        errors.add(:recorded_date, message)
        self
      end
    end
  end

end
