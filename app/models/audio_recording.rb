require 'digest'
require 'digest/md5'

class AudioRecording < ActiveRecord::Base

  extend Enumerize

  # attr
  attr_accessible :bit_rate_bps, :channels, :data_length_bytes, :original_file_name,
                  :duration_seconds, :file_hash, :media_type, :notes,
                  :recorded_date, :sample_rate_hertz, :status, :uploader_id,
                  :site_id
  attr_protected :uuid

  # relations
  belongs_to :site, inverse_of: :audio_recordings
  has_many :audio_events, inverse_of: :audio_recording
  #has_many :analysis_items
  has_many :bookmarks, inverse_of: :audio_recording
  has_many :tags, through: :audio_events

  belongs_to :owner, class_name: 'User', foreign_key: :creator_id
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id
  belongs_to :uploader, class_name: 'User', foreign_key: :uploader_id

  accepts_nested_attributes_for :site

  # userstamp
  stampable
  #acts_as_paranoid
  #validates_as_paranoid

  # Enums
  AVAILABLE_STATUSES = [:new, :to_check, :ready, :corrupt, :ignore].map { |item| item.to_s }
  enumerize :status, in: AVAILABLE_STATUSES, predicates: true

  # Validations
  validates :status, :inclusion => {in: AVAILABLE_STATUSES}, :presence => true
  validates :uuid, :presence => true, :length => {:is => 36}, :uniqueness => {:case_sensitive => false}
  validates :uploader_id, :presence => true
  validates :recorded_date, :presence => true, :timeliness => {:on_or_before => lambda { Date.current }, :type => :date}
  validates :site, :presence => true
  validates :duration_seconds, :presence => true, :numericality => {greater_than_or_equal_to: 0}
  validates :sample_rate_hertz, :numericality => {only_integer: true, greater_than_or_equal_to: 0}
  # the channels field encodes our special version of a bit flag. 0 (no bits flipped) represents
  # a mix down option - we don't store mix downs (if we did they would be stored as single channel / mono (value = 1))
  validates :channels, :presence => true, :numericality => {:only_integer => true, :greater_than => 0}
  validates :bit_rate_bps, :numericality => {:only_integer => true, :greater_than_or_equal_to => 0}
  validates :media_type, :presence => true
  validates :data_length_bytes, :presence => true, :numericality => {:only_integer => true, :greater_than_or_equal_to => 0}
  validates :file_hash, :presence => true

  before_validation :set_uuid, :on => :create

  # postgres-specific

  scope :start_after, lambda { |time| where('recorded_date >= ?', time) }
  scope :start_before, lambda { |time| where('recorded_date <= ?', time) }
  scope :end_after, lambda { |time| where('recorded_date + CAST(duration_seconds || \' seconds\' as interval)  >= ?', time) }
  scope :end_before, lambda { |time| where('end_time_seconds + CAST(duration_seconds || \'seconds\' as interval) <= ?', time) }
  scope :has_tag, lambda { |tag| includes(:tags).where('tags.text = ?', tag) }
  scope :has_tags, lambda { |tags| includes(:tags).where('tags.text IN ?', tags) }
  scope :does_not_have_tag, lambda { |tag| includes(:tags).where('tags.text <> ?', tag) }
  scope :does_not_have_tags, lambda { |tags| includes(:tags).where('tags.text NOT IN ?', tags) }
  scope :tag_count, lambda { |num_tags| includes(:tags).where('audio_events_tags.tag_id' => Tagging.select(:tag_id).group(:tag_id).having('count(tag_id) > ?', num_tags)) }
  scope :tag_types, lambda { |tag_types| includes(:tags).where('tags.type_of_tag' => tag_types) }
  scope :tag_text, lambda { |tag_text| includes(:tags).where(Tag.arel_table[:text].matches("%#{tag_text}%")) }

  def original_file_exists?
    self.original_file_paths.length > 0
  end

  def original_file_paths
    cache = Settings.cache_tool

    original_format = '.wv' # pick something

    if !self.original_file_name.blank?
      original_format = File.extname(self.original_file_name)
    elsif !self.media_type.blank?
      original_format = Mime::Type.file_extension_of(self.media_type)
    end

    source_existing_paths = []
    unless original_format.blank?
      file_name = cache.original_audio.file_name(self.uuid, self.recorded_date, self.recorded_date, original_format)
      source_existing_paths = cache.existing_storage_paths(cache.original_audio, file_name)
    end

    source_existing_paths
  end

  def check_file_hash
    # ensure this audio recording needs to be checked
    return if self.status != 'to_check'

    # type of hash is at start of hash_to_compare, split using two colons
    hash_type, compare_hash = self.file_hash.split('::')

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
    if incr_hash.hexdigest.upcase == compare_hash
      self.status = 'ready'
      self.save!
    else
      self.status = 'corrupt'
      self.save!
      raise "Audio recording was not verified successfully: #{self.uuid}."
    end
  end

  def check_status
    case self.status.to_s
      when 'new'
        raise "Audio recording is not yet ready to be accessed: #{self.uuid}."
      when 'to_check'
        # check the original file hash
        self.check_file_hash
      when 'corrupt'
        raise "Audio recording is corrupt and cannot be accessed: #{self.uuid}."
      when 'ignore'
        raise "Audio recording is ignored and may not be accessed: #{self.uuid}."
      else
    end
  end

  def generate_spectrogram(modify_parameters = {})
    cache = Settings.cache_tool
# first check if a cached spectrogram matches the request

    target_file = cache.cache_spectrogram.file_name(modify_parameters)
    target_existing_paths = cache.existing_storage_paths(cache.cache_spectrogram, target_file)

    if target_existing_paths.blank?
      # if no cached spectrogram images exist, try to create them from the cached audio (it must be a wav file)
      cached_wav_audio_parameters = modify_parameters.clone
      cached_wav_audio_parameters[:format] = 'wav'

      source_file = cache.cached_audio_file(cached_wav_audio_parameters)
      source_existing_paths = cache.existing_cached_audio_paths(source_file)

      if source_existing_paths.blank?
        # change the format to wav, so spectrograms can be created from the audio
        audio_modify_parameters = modify_parameters.clone
        audio_modify_parameters[:format] = 'wav'

        # if no cached audio files exist, try to create them
        create_audio_segment(audio_modify_parameters)
        source_existing_paths = cache.existing_cached_audio_paths(source_file)
        # raise an exception if the cached audio files could not be created
        raise Exceptions::AudioFileNotFoundError, "Could not generate spectrogram." if source_existing_paths.blank?
      end

      # create the spectrogram image in each of the possible paths
      target_possible_paths = cache.possible_cached_spectrogram_paths(target_file)
      target_possible_paths.each { |path|
        # ensure the subdirectories exist
        FileUtils.mkpath(File.dirname(path))
        # generate the spectrogram
        Spectrogram::generate(source_existing_paths.first, path, modify_parameters)
      }
      target_existing_paths = cache.existing_cached_spectrogram_paths(target_file)

      raise Exceptions::SpectrogramFileNotFoundError, "Could not find spectrogram." if target_existing_paths.blank?
    end

    # the requested spectrogram image should exist in at least one possible path
    # return the first existing full path
    target_existing_paths.first
  end

  def modify_audio(modify_parameters = {})
    cache = Settings.cache_tool
# first check if a cached audio file matches the request
    target_file = cache.cached_audio_file(modify_parameters)
    target_existing_paths = cache.existing_cached_audio_paths(target_file)

    if target_existing_paths.blank?
      # if no cached audio files exist, try to create them from the original audio
      source_file = cache.original_audio_file(modify_parameters)
      source_existing_paths = cache.existing_original_audio_paths(source_file)
      source_possible_paths = cache.possible_original_audio_paths(source_file)

      # if the original audio files cannot be found, raise an exception
      raise Exceptions::AudioFileNotFoundError, "Could not find original audio in '#{source_possible_paths}'." if source_existing_paths.blank?

      audio_recording = AudioRecording.where(:id => modify_parameters[:id]).first!

      # check audio file status
      case audio_recording.status
        when :new
          raise "Audio recording is not yet ready to be accessed: #{audio_recording.uuid}."
        when :to_check
          # check the original file hash
          check_file_hash(source_existing_paths.first, audio_recording)
        when :corrupt
          raise "Audio recording is corrupt and cannot be accessed: #{audio_recording.uuid}."
        when :ignore
          raise "Audio recording is ignored and may not be accessed: #{audio_recording.uuid}."
        else
      end

      raise "Audio recording was not ready: #{audio_recording.uuid}." unless audio_recording.status.to_sym == :ready

      # create the cached audio file in each of the possible paths
      target_possible_paths = cache.possible_cached_audio_paths(target_file)
      target_possible_paths.each { |path|
        # ensure the subdirectories exist
        FileUtils.mkpath(File.dirname(path))
        # create the audio segment
        Audio::modify(source_existing_paths.first, path, modify_parameters)
      }
      target_existing_paths = cache.existing_cached_audio_paths(target_file)
    end

    # the requested audio file should exist in at least one possible path
    # return the first existing full path
    target_existing_paths.first
  end

  private
  def set_uuid
    self.uuid = UUIDTools::UUID.random_create.to_s
  end

end
