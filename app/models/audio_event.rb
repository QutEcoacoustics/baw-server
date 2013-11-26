class AudioEvent < ActiveRecord::Base

  attr_accessible :audio_recording_id, :start_time_seconds, :end_time_seconds, :low_frequency_hertz, :high_frequency_hertz, :is_reference,
                  :tags_attributes, :tag_ids

  # relations
  belongs_to :audio_recording, inverse_of: :audio_events
  has_many :taggings # no inverse of specified, as it interferes with through: association
  has_many :tags, through: :taggings
  belongs_to :owner, class_name: 'User', foreign_key: :creator_id
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id


  accepts_nested_attributes_for :tags


  # userstamp
  stampable
  #acts_as_paranoid
  #validates_as_paranoid

  # validation
  validates :audio_recording, presence: true
  validates :is_reference, inclusion: {in: [true, false]}

  validates :start_time_seconds, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :end_time_seconds, numericality: {greater_than_or_equal_to: 0}, allow_nil: true
  validates :low_frequency_hertz, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :high_frequency_hertz, numericality: {greater_than_or_equal_to: 0}, allow_nil: true

  validate :start_must_be_lte_end
  validate :low_must_be_lte_high

  before_validation :set_tags , on: :create


  # Scopes
  scope :start_after, lambda { |offset_seconds| where('start_time_seconds > ?', offset_seconds)}
  scope :start_before, lambda { |offset_seconds| where('start_time_seconds < ?', offset_seconds)}
  scope :end_after, lambda { |offset_seconds| where('end_time_seconds > ?', offset_seconds)}
  scope :end_before, lambda { |offset_seconds| where('end_time_seconds < ?', offset_seconds)}

  private

  # custom validation methods
  def start_must_be_lte_end
    return unless end_time_seconds && start_time_seconds

    if start_time_seconds > end_time_seconds then
      errors.add(:start_time_seconds, 'must be lower than end time')
    end
  end

  def low_must_be_lte_high
    return unless high_frequency_hertz && low_frequency_hertz

    if low_frequency_hertz > high_frequency_hertz then
      errors.add(:start_time_seconds, 'must be lower than high frequency')
    end
  end

  def set_tags
    existing_tags = []
    new_tags = []

    tags.each do |tag|
      existing_tag = Tag.find_by_text(tag.text)
      if existing_tag
        existing_tags << existing_tag
      else
        new_tags << tag
      end
    end

    self.tags = new_tags + existing_tags
  end
end