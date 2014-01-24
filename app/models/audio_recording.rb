require './lib/modules/media_cacher'

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
  enumerize :status, in: AVAILABLE_STATUSES, predicates: true, multiple: false

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

    cache = Cache::Cache.new(Settings.paths.original_audios, Settings.paths.cached_audios, nil, nil, nil)

    file_name_params = {
        :uuid => self.uuid,
        :date => self.recorded_date.strftime("%y%m%d"),
        :time => self.recorded_date.strftime("%H%M")
    }

    if !self.original_file_name.blank?
      file_name_params[:original_format] = File.extname(self.original_file_name)
    elsif !self.media_type.blank?
      file_name_params[:original_format] = Mime::Type.file_extension_of(self.media_type)
    else
      file_name_params[:original_format] = '.wv' # pick something
    end

    if file_name_params[:original_format].blank?
      false
    else
      file_name_params[:original_format] = file_name_params[:original_format].downcase
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
