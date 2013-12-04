require './lib/modules/media_cacher'

class AudioRecording < ActiveRecord::Base

  extend Enumerize

  # attr
  attr_accessible :bit_rate_bps, :channels, :data_length_bytes, :original_file_name,
                  :duration_seconds, :file_hash, :media_type, :notes,
                  :recorded_date, :sample_rate_hertz, :status, :uploader_id,
                  :site_id
  attr_protected  :uuid

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

  scope :start_after, lambda { |time| where('recorded_date >= ?', time)}
  scope :start_before, lambda { |time| where('recorded_date <= ?', time)}
  scope :end_after, lambda { |time| where('recorded_date + duration_seconds >= ?', time)}
  scope :end_before, lambda { |time| where('end_time_seconds + duration_seconds <= ?', time)}

  def original_file_exists?

    cache = Cache::Cache.new(Settings.paths.original_audios, Settings.paths.cached_audios, nil, nil, nil)

    file_name_params = {
        :uuid => self.uuid,
        :date => self.recorded_date.strftime("%Y%m%d"),
        :time => self.recorded_date.strftime("%H%M%S"),
        :original_format => File.extname(self.original_file_name)
    }

    if file_name_params[:original_format].blank?
      file_name_params[:original_format] = Mime::Type.file_extension_of(self.media_type)
    end

    if file_name_params[:original_format].blank?
      false
    else
      file_name = cache.original_audio_file(file_name_params)
      source_possible_paths = cache.existing_original_audio_paths(file_name)
      source_possible_paths.length > 0
    end
  end

  private
  def set_uuid
    self.uuid = UUIDTools::UUID.random_create.to_s
  end

end
