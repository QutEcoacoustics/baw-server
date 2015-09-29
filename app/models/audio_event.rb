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

          # do a query for the attributes that may not be in the projection
          fresh_audio_event = AudioEvent.find(audio_event.id)

          audio_event_hash = {}

          audio_event_hash[:taggings] =
              Tagging
                  .where(audio_event_id: fresh_audio_event.id)
                  .select(:id, :audio_event_id, :tag_id, :created_at, :updated_at, :creator_id, :updater_id)

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

  # Project audio events to the format for CSV download
  # @return  [Arel::Nodes::Node] audio event csv query
  def self.csv_query(project, site, audio_recording, start_offset, end_offset)

    audio_events = AudioEvent.arel_table
    users = User.arel_table
    audio_recordings = AudioRecording.arel_table
    sites = Site.arel_table
    projects = Project.arel_table
    projects_sites = Arel::Table.new(:projects_sites)
    audio_events_tags = Tagging.arel_table
    tags = Tag.arel_table

    format_date = Arel::Nodes.build_quoted('YYYY-MM-DD')
    format_time = Arel::Nodes.build_quoted('HH24:MI:SS')
    format_iso8601 = Arel::Nodes.build_quoted('YYYY-MM-DD"T"HH24:MI:SS"Z"')

    audio_event_start_abs =
        Arel::Nodes::SqlLiteral.new(
            '"audio_recordings"."recorded_date" + CAST("audio_events"."start_time_seconds" || \' seconds\' as interval)')

    projects_agg = Arel::Nodes::SqlLiteral.new(
        'string_agg(CAST("projects"."id" as varchar) || \':\' || "projects"."name", \'|\')')
    simple_tags_agg = Arel::Nodes::SqlLiteral.new(
        'string_agg(CAST("tags"."id" as varchar) || \':\' || "tags"."text", \'|\')')
    simple_tags_ids = Arel::Nodes::SqlLiteral.new(
        'string_agg(CAST("tags"."id" as varchar), \'|\')')
    other_tags_agg = Arel::Nodes::SqlLiteral.new(
        'string_agg(CAST("tags"."id" as varchar) || \':\' || "tags"."text" || \':\' || "tags"."type_of_tag", \'|\')')
    other_tags_ids = Arel::Nodes::SqlLiteral.new(
        'string_agg(CAST("tags"."id" as varchar), \'|\')')

    url_base = "http://#{Settings.host.name}/"

    projects_aggregate =
        projects_sites
            .join(projects).on(projects[:id].eq(projects_sites[:project_id]))
            .where(projects_sites[:site_id].eq(sites[:id]))
            .project(projects_agg)

    tags_common =
        tags
            .join(audio_events_tags).on(audio_events_tags[:tag_id].eq(tags[:id]))
            .where(audio_events_tags[:audio_event_id].eq(audio_events[:id]))
            .where(tags[:type_of_tag].eq('common_name'))

    tags_common_aggregate = tags_common.clone.project(simple_tags_agg)
    tags_common_ids = tags_common.clone.project(simple_tags_ids)

    tags_species =
        tags
            .join(audio_events_tags).on(audio_events_tags[:tag_id].eq(tags[:id]))
            .where(audio_events_tags[:audio_event_id].eq(audio_events[:id]))
            .where(tags[:type_of_tag].eq('species_name'))

    tags_species_aggregate = tags_species.clone.project(simple_tags_agg)
    tags_species_ids = tags_species.clone.project(simple_tags_ids)

    tags_others =
        tags
            .join(audio_events_tags).on(audio_events_tags[:tag_id].eq(tags[:id]))
            .where(audio_events_tags[:audio_event_id].eq(audio_events[:id]))
            .where(tags[:type_of_tag].in(['species_name', 'common_name']).not)

    tags_others_aggregate = tags_others.clone.project(other_tags_agg)
    tags_others_ids = tags_others.clone.project(other_tags_ids)

    query =
        audio_events
            .join(users).on(users[:id].eq(audio_events[:creator_id]))
            .join(audio_recordings).on(audio_recordings[:id].eq(audio_events[:audio_recording_id]))
            .join(sites).on(sites[:id].eq(audio_recordings[:site_id]))
            .order(audio_events[:id].desc)
            .project(
                audio_events[:id].as('audio_event_id'),
                audio_recordings[:id].as('audio_recording_id'),
                audio_recordings[:uuid].as('audio_recording_uuid'),

                Arel::Nodes::NamedFunction.new('to_char', [audio_recordings[:recorded_date], format_date]).as('audio_recording_start_date_utc'),
                Arel::Nodes::NamedFunction.new('to_char', [audio_recordings[:recorded_date], format_time]).as('audio_recording_start_time_utc'),
                Arel::Nodes::NamedFunction.new('to_char', [audio_recordings[:recorded_date], format_iso8601]).as('audio_recording_start_datetime_utc'),

                Arel::Nodes::NamedFunction.new('to_char', [audio_events[:created_at], format_date]).as('event_created_at_date_utc'),
                Arel::Nodes::NamedFunction.new('to_char', [audio_events[:created_at], format_time]).as('event_created_at_time_utc'),
                Arel::Nodes::NamedFunction.new('to_char', [audio_events[:created_at], format_iso8601]).as('event_created_at_datetime_utc'),

                projects_aggregate.as('projects'),
                sites[:id].as('site_id'),
                sites[:name].as('site_name'),

                Arel::Nodes::NamedFunction.new('to_char', [audio_event_start_abs, format_date]).as('event_start_date_utc'),
                Arel::Nodes::NamedFunction.new('to_char', [audio_event_start_abs, format_time]).as('event_start_time_utc'),
                Arel::Nodes::NamedFunction.new('to_char', [audio_event_start_abs, format_iso8601]).as('event_start_datetime_utc'),

                audio_events[:start_time_seconds].as('event_start_seconds'),
                audio_events[:end_time_seconds].as('event_end_seconds'),
                Arel::Nodes::InfixOperation.new(:-, audio_events[:end_time_seconds], audio_events[:start_time_seconds]).as('event_duration_seconds'),
                audio_events[:low_frequency_hertz].as('low_frequency_hertz'),
                audio_events[:high_frequency_hertz].as('high_frequency_hertz'),
                audio_events[:is_reference].as('is_reference'),
                audio_events[:creator_id].as('created_by'),
                audio_events[:updater_id].as('updated_by'),

                tags_common_aggregate.as('common_name_tags'),
                tags_common_ids.as('common_name_tag_ids'),

                tags_species_aggregate.as('species_name_tags'),
                tags_species_ids.as('species_name_tag_ids'),

                tags_others_aggregate.as('other_tags'),
                tags_others_ids.as('other_tag_ids'),

                Arel::Nodes::SqlLiteral.new(
                    "'#{url_base}" + 'listen/\'|| "audio_recordings"."id" || \'?start=\' || ' +
                        '(floor("audio_events"."start_time_seconds" / 30) * 30) || ' +
                        '\'&end=\' || ((floor("audio_events"."start_time_seconds" / 30) * 30) + 30)')
                    .as('listen_url'),

                Arel::Nodes::SqlLiteral.new(
                    "'#{url_base}" + 'library/\' || "audio_recordings"."id" || \'/audio_events/\' || audio_events.id')
                    .as('library_url'),
            )

    if project

      site_ids = sites
                     .join(projects_sites).on(sites[:id].eq(projects_sites[:site_id]))
                     .join(projects).on(projects[:id].eq(projects_sites[:project_id]))
                     .where(projects[:id].eq(project.id))
                     .project(sites[:id]).distinct

      query = query.where(sites[:id].in(site_ids))
    end

    if site
      query = query.where(sites[:id].eq(site.id))
    end

    if audio_recording
      query = query.where(audio_recordings[:id].eq(audio_recording.id))
    end

    if start_offset
      query = query.where(audio_events[:end_time_seconds].gteq(start_offset))
    end

    if end_offset
      query = query.where(audio_events[:start_time_seconds].lteq(end_offset))
    end

    query
  end

  def self.in_site(site)
    AudioEvent
        .joins(:audio_recording)
        .includes(:updater, :creator)
        .where(audio_recordings: {site_id: site.id})
        .order(updated_at: :desc)
        .limit(6)
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