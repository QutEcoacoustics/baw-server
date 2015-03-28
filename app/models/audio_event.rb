class AudioEvent < ActiveRecord::Base
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # relations
  belongs_to :audio_recording, inverse_of: :audio_events
  has_many :taggings, inverse_of: :audio_event
  has_many :tags, through: :taggings

  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id', inverse_of: :created_audio_events
  belongs_to :updater, class_name: 'User', foreign_key: 'updater_id', inverse_of: :updated_audio_events
  belongs_to :deleter, class_name: 'User', foreign_key: 'deleter_id', inverse_of: :deleted_audio_events
  has_many :comments, class_name: 'AudioEventComment', foreign_key: 'audio_event_id', inverse_of: :audio_event

  accepts_nested_attributes_for :tags


  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # association validations
  validates :audio_recording, existence: true
  validates :creator, existence: true

  # validation
  validates :is_reference, inclusion: {in: [true, false]}
  validates :start_time_seconds, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :end_time_seconds, numericality: {greater_than_or_equal_to: 0}, allow_nil: true
  validates :low_frequency_hertz, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :high_frequency_hertz, numericality: {greater_than_or_equal_to: 0}, allow_nil: true

  validate :start_must_be_lte_end
  validate :low_must_be_lte_high

  before_validation :set_tags, on: :create

  # Scopes
  scope :start_after, lambda { |offset_seconds| where('start_time_seconds > ?', offset_seconds) }
  scope :start_before, lambda { |offset_seconds| where('start_time_seconds < ?', offset_seconds) }
  scope :end_after, lambda { |offset_seconds| where('end_time_seconds > ?', offset_seconds) }
  scope :end_before, lambda { |offset_seconds| where('end_time_seconds < ?', offset_seconds) }

  # postgres-specific
  scope :select_start_absolute, lambda { select('audio_recordings.recorded_date + CAST(audio_events.start_time_seconds || \' seconds\' as interval) as start_time_absolute') }
  scope :select_end_absolute, lambda { select('audio_recordings.recorded_date + CAST(audio_events.end_time_seconds || \' seconds\' as interval) as end_time_absolute') }

  # Define filter api settings
  def self.filter_settings
    {
        valid_fields: [:id, :audio_recording_id,
                       :start_time_seconds, :end_time_seconds,
                       :low_frequency_hertz, :high_frequency_hertz,
                       :is_reference,
                       :created_at, :creator_id, :updated_at,
                       :duration_seconds],
        render_fields: [:id, :audio_recording_id,
                        :start_time_seconds, :end_time_seconds,
                        :low_frequency_hertz, :high_frequency_hertz,
                        :is_reference,
                        :creator_id, :updated_at, :created_at],
        text_fields: [],
        custom_fields: lambda { |audio_event, user|
          audio_event_hash = {}

          audio_event_hash[:taggings] = Tagging
                                    .where(audio_event_id: audio_event.id)
                                    .select(:id, :audio_event_id, :created_at, :updated_at, :creator_id, :updater_id)

          [audio_event, audio_event_hash]
        },
        controller: :audio_events,
        action: :filter,
        defaults: {
            order_by: :created_at,
            direction: :desc
        },
        field_mappings: [
            {
                name: :duration_seconds,
                value: (AudioEvent.arel_table[:end_time_seconds] - AudioEvent.arel_table[:start_time_seconds])
            }
        ],
        valid_associations: [
            {
                join: AudioRecording,
                on: AudioEvent.arel_table[:audio_recording_id].eq(AudioRecording.arel_table[:id]),
                available: true
            },
            {
                join: AudioEventComment,
                on: AudioEvent.arel_table[:id].eq(AudioEventComment.arel_table[:audio_event_id]),
                available: true
            },
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
    }
  end

  def self.csv_filter(user, filter_params)
    query = Access::Query.audio_events(user, :reader).joins(:creator, :tags)

    if filter_params[:project_id]
      query = query.where(projects: {id: (filter_params[:project_id]).to_i})
    end

    if filter_params[:site_id]
      query = query.where(sites: {id: (filter_params[:site_id]).to_i})
    end

    if filter_params[:audio_recording_id] || filter_params[:audiorecording_d] || filter_params[:recording_id]
      query = query.where(audio_recordings: {id: (filter_params[:audio_recording_id] || filter_params[:audiorecording_d] || filter_params[:recording_id]).to_i})
    end

    if filter_params[:start_offset]
      query = query.end_after(filter_params[:start_offset])
    end

    if filter_params[:end_offset]
      query = query.start_before(filter_params[:end_offset])
    end

    query.order('audio_events.id DESC')
  end

  def self.in_site(site)
    AudioEvent.find_by_sql(["SELECT ae.*
FROM audio_events ae
INNER JOIN audio_recordings ar ON ae.audio_recording_id = ar.id
INNER JOIN sites s ON ar.site_id = s.id
WHERE s.id = :site_id
ORDER BY ae.updated_at DESC
LIMIT 6", {site_id: site.id}])
  end

  private

  # custom validation methods
  def start_must_be_lte_end
    return unless end_time_seconds && start_time_seconds

    if start_time_seconds > end_time_seconds
      errors.add(:start_time_seconds, '%{value} must be lower than end time')
    end
  end

  def low_must_be_lte_high
    return unless high_frequency_hertz && low_frequency_hertz

    if low_frequency_hertz > high_frequency_hertz
      errors.add(:start_time_seconds, '%{value} must be lower than high frequency')
    end
  end

  def set_tags

    # for each tagging, check if a tag with that text already exists
    # if one does, delete that tagging and add the existing tag

    tag_ids_to_add = []

    self.taggings.each do |tagging|
      tag = tagging.tag
      # ensure string comparison is case insensitive
      existing_tag = Tag.where('lower(text) = ?', tag.text.downcase).first

      unless existing_tag.blank?
        #remove the tag association, otherwise it tries to create the tag and fails (as the tag already exists)
        self.tags.each do |audio_event_tag|
          # The collection.delete method removes one or more objects from the collection by setting their foreign keys to NULL.
          # ensure string comparison is case insensitive
          self.tags.delete(audio_event_tag) if existing_tag.text.downcase == audio_event_tag.text.downcase
        end

        # remove the tagging association
        self.taggings.delete(tagging)

        # record the tag id
        tag_ids_to_add.push(existing_tag.id)
      end
    end

    # add the tagging using the existing tag id
    tag_ids_to_add.each do |tag_id|
      self.taggings << Tagging.new(tag_id: tag_id)
    end

  end

end