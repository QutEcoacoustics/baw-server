# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_events
#
#  id                                                                              :integer          not null, primary key
#  channel                                                                         :integer
#  deleted_at                                                                      :datetime
#  end_time_seconds                                                                :decimal(10, 4)
#  high_frequency_hertz                                                            :decimal(10, 4)
#  import_file_index(Index of the row/entry in the file that generated this event) :integer
#  is_reference                                                                    :boolean          default(FALSE), not null
#  low_frequency_hertz                                                             :decimal(10, 4)
#  score(Score or confidence for this event.)                                      :decimal(, )
#  start_time_seconds                                                              :decimal(10, 4)   not null
#  created_at                                                                      :datetime
#  updated_at                                                                      :datetime
#  audio_event_import_file_id                                                      :integer
#  audio_recording_id                                                              :integer          not null
#  creator_id                                                                      :integer          not null
#  deleter_id                                                                      :integer
#  provenance_id(Source of this event)                                             :integer
#  updater_id                                                                      :integer
#
# Indexes
#
#  index_audio_events_on_audio_event_import_file_id  (audio_event_import_file_id)
#  index_audio_events_on_audio_recording_id          (audio_recording_id)
#  index_audio_events_on_creator_id                  (creator_id)
#  index_audio_events_on_deleter_id                  (deleter_id)
#  index_audio_events_on_provenance_id               (provenance_id)
#  index_audio_events_on_updater_id                  (updater_id)
#
# Foreign Keys
#
#  audio_events_audio_recording_id_fk  (audio_recording_id => audio_recordings.id) ON DELETE => cascade
#  audio_events_creator_id_fk          (creator_id => users.id)
#  audio_events_deleter_id_fk          (deleter_id => users.id)
#  audio_events_updater_id_fk          (updater_id => users.id)
#  fk_rails_...                        (audio_event_import_file_id => audio_event_import_files.id) ON DELETE => cascade
#  fk_rails_...                        (provenance_id => provenances.id)
#
class AudioEvent < ApplicationRecord
  # relations
  belongs_to :audio_recording, inverse_of: :audio_events
  belongs_to :audio_event_import_file, inverse_of: :audio_events, optional: true
  belongs_to :provenance, optional: true

  has_many :taggings, inverse_of: :audio_event, strict_loading: false, dependent: :destroy
  has_many :tags, through: :taggings

  belongs_to :creator, class_name: 'User', inverse_of: :created_audio_events
  belongs_to :updater, class_name: 'User', inverse_of: :updated_audio_events, optional: true
  belongs_to :deleter, class_name: 'User', inverse_of: :deleted_audio_events, optional: true
  has_many :comments, class_name: 'AudioEventComment', inverse_of: :audio_event, dependent: :delete_all
  has_many :verifications, inverse_of: :audio_event, dependent: :destroy

  # AT 2021: disabled. Nested associations are extremely complex,
  # and as far as we are aware, they are not used anywhere in production
  # TODO: remove on passing test suite
  #accepts_nested_attributes_for :tags

  # add deleted_at and deleter_id
  acts_as_discardable
  also_discards :comments, batch: true

  # association validations
  # disabled because they're annoying - no really they're not needed because associated models are always valid
  #validates_associated :audio_recording
  #validates_associated :creator

  # validation
  validates :is_reference, inclusion: { in: [true, false] }
  validates :start_time_seconds, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :end_time_seconds, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  # AT 2025: changed to allow nil. This is a rather significant change and could break older clients.
  # Unfortunately the reality is that many new recognizers do not provide frequency data.
  # We also previously supported nil lower frequency via audio event imports, so relaxing this constraint
  # is necessary to match import behaviour.
  validates :low_frequency_hertz, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :high_frequency_hertz, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :channel, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validate :start_must_be_lte_end
  validate :low_must_be_lte_high

  # AT 2021: disabled. Nested associations are extremely complex,
  # and as far as we are aware, they are not used anywhere in production
  # TODO: remove on passing test suite
  #before_validation :set_tags, on: :create

  # Scopes
  scope :start_after, ->(offset_seconds) { where('start_time_seconds > ?', offset_seconds) }
  scope :start_before, ->(offset_seconds) { where(start_time_seconds: ...offset_seconds) }
  scope :end_after, ->(offset_seconds) { where('end_time_seconds > ?', offset_seconds) }
  scope :end_before, ->(offset_seconds) { where(end_time_seconds: ...offset_seconds) }

  # postgres-specific
  scope(:select_start_absolute, lambda {
                                  select('audio_recordings.recorded_date + CAST(audio_events.start_time_seconds || \' seconds\' as interval) as start_time_absolute')
                                })
  scope(:select_end_absolute, lambda {
                                select('audio_recordings.recorded_date + CAST(audio_events.end_time_seconds || \' seconds\' as interval) as end_time_absolute')
                              })
  scope :duration_seconds, -> { arel_table[:end_time_seconds] - arel_table[:start_time_seconds] }

  scope :total_duration_seconds, -> { sum(duration_seconds.cast('bigint')) }

  scope(:by_import, lambda { |import_id|
    raise ArgumentError, 'import_id must be an integer' unless import_id.is_a?(Integer)

    joins(:audio_event_import_file)
      .where(
      AudioEventImportFile
        .arel_table[:audio_event_import_id]
        .eq(import_id)
    )
  })

  def self.start_date_arel
    Arel.grouping(
      AudioRecording.arel_table[:recorded_date] +
      arel_table[:start_time_seconds].seconds
    )
  end

  def self.end_date_arel
    Arel.grouping(
      AudioRecording.arel_table[:recorded_date] +
      arel_table[:end_time_seconds].seconds
    )
  end

  # Get the associated taggings as an array of json objects
  # @return [Arel::SelectManager]
  def self.associated_taggings_arel
    taggings = Tagging.arel_table
    inner_table = Arel::Table.new(:taggings_inner)

    inner = taggings
      .project(taggings[:id], taggings[:audio_event_id], taggings[:tag_id], taggings[:created_at], taggings[:updated_at], taggings[:creator_id], taggings[:updater_id])
      .where(taggings[:audio_event_id].eq(arel_table[:id]))
      .ast

    Arel::SelectManager
      .new(Arel.grouping(inner)
      .as(inner_table.name))
      .project(Arel.sql(inner_table.name).row_to_json.json_agg)
      .ast => outer

    Arel.grouping(outer)
  end

  def self.associated_verification_ids_arel
    verifications = Verification.arel_table
    inner_table = Arel::Table.new(:verifications_inner)

    inner = verifications
      .project(verifications[:id])
      .where(verifications[:audio_event_id].eq(arel_table[:id]))
      .ast

    Arel::SelectManager
      .new(Arel.grouping(inner)
      .as(inner_table.name))
      .project(Arel.sql(inner_table.name).array_agg)
      .ast => outer

    Arel.grouping(outer)
  end

  def self.verification_summary_arel
    verifications = Verification.arel_table
    inner_table = Arel::Table.new(:verifications_inner)

    confirmation_columns = Verification::CONFIRMATION_ENUM.values.map { |value|
      verifications[:confirmed].count.filter(verifications[:confirmed].eq(value)).as(value)
    }

    inner = verifications
      .project(
        verifications[:tag_id],
        verifications[Arel.star].count.as('count'),
        *confirmation_columns
      )
      .where(verifications[:audio_event_id].eq(arel_table[:id]))
      .group(verifications[:tag_id])
      .ast

    Arel::SelectManager
      .new(Arel.grouping(inner)
      .as(inner_table.name))
      .project(Arel.sql(inner_table.name).row_to_json.json_agg)
      .ast => outer

    Arel.grouping(outer)
  end

  # Allows this model to infer its timezone when included with larger queries
  # constructed by filter args.
  def self.with_timezone
    {
      model: Site,
      joins: { audio_recording: :site },
      column: :tzinfo_tz
    }
  end

  # Define filter api settings
  def self.filter_settings
    {
      valid_fields: [:id, :audio_recording_id,
                     :start_time_seconds, :end_time_seconds,
                     :low_frequency_hertz, :high_frequency_hertz,
                     :is_reference,
                     :created_at, :creator_id, :updated_at,
                     :duration_seconds,
                     :audio_event_import_file_id, :import_file_index, :provenance_id, :channel, :score,
                     :start_date, :end_date,
                     # this one is rendered by default for back compatibility
                     :taggings,
                     # these two are intentionally not rendered by default
                     :verification_ids, :verification_summary],
      render_fields: [:id, :audio_recording_id,
                      :start_time_seconds, :end_time_seconds,
                      :low_frequency_hertz, :high_frequency_hertz,
                      :is_reference,
                      :creator_id, :updated_at, :created_at,
                      :audio_event_import_file_id, :import_file_index, :provenance_id, :channel, :score,
                      :taggings],
      custom_fields2: {
        duration_seconds: {
          query_attributes: [],
          transform: nil,
          arel: AudioEvent.duration_seconds,
          type: :decimal
        },
        start_date: {
          query_attributes: [],
          transform: nil,
          arel: AudioEvent.start_date_arel,
          type: :datetime
        },
        end_date: {
          query_attributes: [],
          transform: nil,
          arel: AudioEvent.end_date_arel,
          type: :datetime
        },
        taggings: {
          query_attributes: [],
          transform: nil,
          arel: AudioEvent.associated_taggings_arel,
          type: :array
        },
        verification_ids: {
          query_attributes: [],
          transform: nil,
          arel: AudioEvent.associated_verification_ids_arel,
          type: :array
        },
        verification_summary: {
          query_attributes: [],
          transform: nil,
          arel: AudioEvent.verification_summary_arel,
          type: :array
        }
      },
      new_spec_fields: lambda { |_user|
        {
          audio_recording_id: nil,
          start_time_seconds: nil,
          end_time_seconds: nil,
          low_frequency_hertz: nil,
          high_frequency_hertz: nil,
          is_reference: nil,
          tags: []
        }
      },
      controller: :audio_events,
      action: :filter,
      defaults: {
        order_by: :created_at,
        direction: :desc
      },
      valid_associations: [
        {
          join: AudioRecording,
          on: AudioEvent.arel_table[:audio_recording_id].eq(AudioRecording.arel_table[:id]),
          available: true,
          associations: [
            {
              join: Site,
              on: AudioRecording.arel_table[:site_id].eq(Site.arel_table[:id]),
              available: true,
              associations: [
                {
                  join: Region,
                  on: Site.arel_table[:region_id].eq(Region.arel_table[:id]),
                  available: true
                  # TODO: re-enable when we finally remove projects_sites
                  # https://github.com/QutEcoacoustics/baw-server/issues/743
                  # associations: [
                  #   {
                  #     join: Project,
                  #     on: Region.arel_table[:project_id].eq(Project.arel_table[:id]),
                  #     available: true
                  #   }
                  # ]
                },
                {
                  join: ProjectsSite,
                  on: Site.arel_table[:id].eq(ProjectsSite.arel_table[:site_id]),
                  available: false,
                  associations: [
                    {
                      join: Project,
                      on: ProjectsSite.arel_table[:project_id].eq(Project.arel_table[:id]),
                      available: true
                    }
                  ]
                }
              ]
            }
          ]
        },
        {
          join: AudioEventImportFile,
          on: AudioEvent.arel_table[:audio_event_import_file_id].eq(AudioEventImportFile.arel_table[:id]),
          available: true,
          associations: [
            {
              join: AudioEventImport,
              on: AudioEventImportFile.arel_table[:audio_event_import_id].eq(AudioEventImport.arel_table[:id]),
              available: true
            }
          ]
        },
        {
          join: AudioEventComment,
          on: AudioEvent.arel_table[:id].eq(AudioEventComment.arel_table[:audio_event_id]),
          available: true
        },
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

        },
        {
          join: Verification,
          on: AudioEvent.arel_table[:id].eq(Verification.arel_table[:audio_event_id]),
          available: true
        }

      ]
    }
  end

  def self.schema
    {
      type: 'object',
      properties: {
        id: Api::Schema.id(nullable: true),
        audio_recording_id: Api::Schema.id(read_only: false),
        start_time_seconds: { type: 'number', readOnly: false },
        end_time_seconds: { type: 'number', readOnly: false },
        low_frequency_hertz: { type: 'number', readOnly: false },
        high_frequency_hertz: { type: 'number', readOnly: false },
        is_reference: { type: 'boolean', readOnly: false },
        **Api::Schema.all_user_stamps,
        duration_seconds: { type: 'number', readOnly: true },
        taggings: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              id: Api::Schema.id,
              audio_event_id: Api::Schema.id,
              tag_id: Api::Schema.id,
              **Api::Schema.updater_and_creator_user_stamps
            }
          }
        },
        verification_ids: {
          type: 'array',
          items: {
            type: Api::Schema.id(read_only: true)
          }
        },
        verification_summary: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              tag_id: Api::Schema.id,
              count: { type: 'integer' },
              confirmed: { type: 'integer' },
              unconfirmed: { type: 'integer' },
              unsure: { type: 'integer' },
              skipped: { type: 'integer' }
            }
          },
          readOnly: true
        },
        audio_event_import_file_id: Api::Schema.id(nullable: true, read_only: true),
        import_file_index: { type: ['null', 'integer'], readOnly: true },
        provenance_id: Api::Schema.id(nullable: true),
        channel: { type: ['null', 'integer'] },
        score: { type: ['null', 'number'], readOnly: true }
      },
      required: [:score]
    }
  end

  # Project audio events to the format for CSV download
  # @return  [Arel::Nodes::Node] audio event csv query
  # @param [User] user
  # @param [Project] project
  # @param [Site] site
  # @param [AudioRecording] audio_recording
  # @param [Float] start_offset
  # @param [Float] end_offset
  # @param [String] timezone_name
  # @return [Arel:SelectManager]
  def self.csv_query(user, project, region, site, audio_recording, start_offset, end_offset, timezone_name)
    # NOTE: if other modifications are made to the default_scope (like acts_as_discardable does),
    # manually constructed queries like this need to be updated to match
    # (search for ':deleted_at' to find the relevant places)

    # NOTE: tried using Arel from ActiveRecord
    # e.g. AudioEvent.all.ast.cores[0].wheres
    # but was more trouble to use than directly constructing Arel
    audio_events = AudioEvent.arel_table
    users = User.arel_table
    audio_recordings = AudioRecording.arel_table
    sites = Site.arel_table
    regions = Region.arel_table
    projects = Project.arel_table
    projects_sites = Arel::Table.new(:projects_sites)
    audio_events_tags = Tagging.arel_table
    tags = Tag.arel_table
    audio_event_import_files = AudioEventImportFile.arel_table
    audio_event_imports = AudioEventImport.arel_table
    active_storage_attachments = ActiveStorage::Attachment.arel_table
    active_storage_blobs = ActiveStorage::Blob.arel_table

    timezone_name = 'UTC' if timezone_name.blank?
    timezone_offset = ActiveSupport::TimeZone.new(timezone_name)
    field_suffix_offset = TimeZoneHelper.offset_seconds_to_formatted(timezone_offset&.utc_offset || 0)
    field_suffix = "#{timezone_offset&.name}_#{field_suffix_offset.gsub('-', 'neg-').gsub('+',
      '')}".parameterize.underscore

    timezone_interval = Arel::Nodes::SqlLiteral.new("INTERVAL '#{timezone_offset.utc_offset} seconds'")
    format_offset = timezone_offset.utc_offset.zero? ? 'Z' : field_suffix_offset

    format_date = Arel::Nodes.build_quoted('YYYY-MM-DD')
    format_time = Arel::Nodes.build_quoted('HH24:MI:SS')
    format_iso8601 = Arel::Nodes.build_quoted("YYYY-MM-DD\"T\"HH24:MI:SS\"#{format_offset}\"")

    audio_event_start_abs =
      Arel::Nodes::SqlLiteral.new(
        '"audio_recordings"."recorded_date" + CAST("audio_events"."start_time_seconds" || \' seconds\' as interval)'
      )

    projects_agg = Arel::Nodes::SqlLiteral.new(
      'string_agg(CAST("projects"."id" as varchar) || \':\' || "projects"."name", \'|\')'
    )
    simple_tags_agg = Arel::Nodes::SqlLiteral.new(
      'string_agg(CAST("tags"."id" as varchar) || \':\' || "tags"."text", \'|\')'
    )
    simple_tags_ids = Arel::Nodes::SqlLiteral.new(
      'string_agg(CAST("tags"."id" as varchar), \'|\')'
    )
    other_tags_agg = Arel::Nodes::SqlLiteral.new(
      'string_agg(CAST("tags"."id" as varchar) || \':\' || "tags"."text" || \':\' || "tags"."type_of_tag", \'|\')'
    )
    other_tags_ids = Arel::Nodes::SqlLiteral.new(
      'string_agg(CAST("tags"."id" as varchar), \'|\')'
    )

    url_base = "http://#{Settings.host.name}/"

    projects_aggregate =
      projects_sites
        .join(projects).on(projects[:id].eq(projects_sites[:project_id]))
        .where(projects[:deleted_at].eq(nil))
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

    verification_cte_table, verification_cte = verification_summary_cte

    query =
      audio_events
        .join(verification_cte_table, Arel::Nodes::OuterJoin)
        .on(audio_events[:id].eq(verification_cte_table[:audio_event_id]))
        .where(audio_events[:deleted_at].eq(nil))
        .join(users).on(users[:id].eq(audio_events[:creator_id]))
        .join(audio_recordings).on(audio_recordings[:id].eq(audio_events[:audio_recording_id]))
        .where(audio_recordings[:deleted_at].eq(nil))
        .join(sites).on(sites[:id].eq(audio_recordings[:site_id]))
        .where(sites[:deleted_at].eq(nil))
        .join(regions, Arel::Nodes::OuterJoin).on(regions[:id].eq(sites[:region_id]))
        .where(regions[:deleted_at].eq(nil))
        .join(audio_event_import_files, Arel::Nodes::OuterJoin)
        .on(audio_event_import_files[:id].eq(audio_events[:audio_event_import_file_id]))
        .join(audio_event_imports, Arel::Nodes::OuterJoin)
        .on(audio_event_imports[:id].eq(audio_event_import_files[:audio_event_import_id]))
        .join(active_storage_attachments, Arel::Nodes::OuterJoin)
        .on(active_storage_attachments[:record_id].eq(audio_event_import_files[:id])
            .and(active_storage_attachments[:record_type].eq('AudioEventImportFile'))
            .and(active_storage_attachments[:name].eq('file')))
        .join(active_storage_blobs, Arel::Nodes::OuterJoin)
        .on(active_storage_blobs[:id].eq(active_storage_attachments[:blob_id]))
        .order(audio_events[:id].desc)
        .with(verification_cte)
        .project(
          audio_events[:id].as('audio_event_id'),
          audio_recordings[:id].as('audio_recording_id'),
          audio_recordings[:uuid].as('audio_recording_uuid'),
          function_datetime_timezone('to_char', audio_recordings[:recorded_date], timezone_interval,
            format_date).as("audio_recording_start_date_#{field_suffix}"),
          function_datetime_timezone('to_char', audio_recordings[:recorded_date], timezone_interval,
            format_time).as("audio_recording_start_time_#{field_suffix}"),
          function_datetime_timezone('to_char', audio_recordings[:recorded_date], timezone_interval,
            format_iso8601).as("audio_recording_start_datetime_#{field_suffix}"),
          function_datetime_timezone('to_char', audio_events[:created_at], timezone_interval,
            format_date).as("event_created_at_date_#{field_suffix}"),
          function_datetime_timezone('to_char', audio_events[:created_at], timezone_interval,
            format_time).as("event_created_at_time_#{field_suffix}"),
          function_datetime_timezone('to_char', audio_events[:created_at], timezone_interval,
            format_iso8601).as("event_created_at_datetime_#{field_suffix}"),
          projects_aggregate.as('projects'),
          regions[:id].as('region_id'),
          regions[:name].as('region_name'),
          sites[:id].as('site_id'),
          sites[:name].as('site_name'),
          function_datetime_timezone('to_char', audio_event_start_abs, timezone_interval,
            format_date).as("event_start_date_#{field_suffix}"),
          function_datetime_timezone('to_char', audio_event_start_abs, timezone_interval,
            format_time).as("event_start_time_#{field_suffix}"),
          function_datetime_timezone('to_char', audio_event_start_abs, timezone_interval,
            format_iso8601).as("event_start_datetime_#{field_suffix}"),
          audio_events[:start_time_seconds].as('event_start_seconds'),
          audio_events[:end_time_seconds].as('event_end_seconds'),
          infix_operation(:-, audio_events[:end_time_seconds],
            audio_events[:start_time_seconds]).as('event_duration_seconds'),
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
          verification_cte_table[:verifications],
          verification_cte_table[:verification_counts],
          verification_cte_table[:verification_correct],
          verification_cte_table[:verification_incorrect],
          verification_cte_table[:verification_skip],
          verification_cte_table[:verification_unsure],
          verification_cte_table[:verification_decisions],
          verification_cte_table[:verification_consensus],
          audio_events[:audio_event_import_file_id].as('audio_event_import_file_id'),
          AudioEventImportFile.name_arel.as('audio_event_import_file_name'),
          audio_event_import_files[:audio_event_import_id].as('audio_event_import_id'),
          audio_event_imports[:name].as('audio_event_import_name'),
          Arel::Nodes::SqlLiteral.new(
            "'#{url_base}" + 'listen/\'|| "audio_recordings"."id" || \'?start=\' || ' \
                             '(floor("audio_events"."start_time_seconds" / 30) * 30) || ' \
                             '\'&end=\' || ((floor("audio_events"."start_time_seconds" / 30) * 30) + 30)'
          )
              .as('listen_url'),
          Arel::Nodes::SqlLiteral.new(
            "'#{url_base}library/' || \"audio_recordings\".\"id\" || '/audio_events/' || audio_events.id"
          )
              .as('library_url')
        )

    # ensure deleted projects are not included
    site_ids_for_live_project_ids = projects
      .where(projects[:deleted_at].eq(nil))
      .join(projects_sites).on(projects[:id].eq(projects_sites[:project_id]))
      .where(sites[:id].eq(projects_sites[:site_id]))
      .project(sites[:id]).distinct

    query = query.where(sites[:id].in(site_ids_for_live_project_ids))

    query = query.where(users[:id].eq(user.id)) if user

    if project
      site_ids = sites
        .join(projects_sites).on(sites[:id].eq(projects_sites[:site_id]))
        .join(projects).on(projects[:id].eq(projects_sites[:project_id]))
        .where(projects[:deleted_at].eq(nil))
        .where(projects[:id].eq(project.id))
        .project(sites[:id]).distinct

      query = query.where(sites[:id].in(site_ids))
    end

    query = query.where(regions[:id].eq(region.id)) if region

    query = query.where(sites[:id].eq(site.id)) if site

    query = query.where(audio_recordings[:id].eq(audio_recording.id)) if audio_recording

    query = query.where(audio_events[:end_time_seconds].gteq(start_offset)) if start_offset

    query = query.where(audio_events[:start_time_seconds].lteq(end_offset)) if end_offset

    query
  end

  def self.in_site(site)
    AudioEvent
      .joins(:audio_recording)
      .includes(:updater, :creator)
      .where(audio_recordings: { site_id: site.id })
      .order(updated_at: :desc)
      .limit(6)
  end

  private

  # custom validation methods
  def start_must_be_lte_end
    return unless end_time_seconds && start_time_seconds

    errors.add(:start_time_seconds, '%<value>s must be lower than end time') if start_time_seconds > end_time_seconds
  end

  def low_must_be_lte_high
    return unless high_frequency_hertz && low_frequency_hertz

    return unless low_frequency_hertz > high_frequency_hertz

    errors.add(:start_time_seconds, '%<value>s must be lower than high frequency')
  end

  # AT 2021: disabled. I can't work out what this code does or what effect is has
  # TODO: remove on passing test suite
  # def set_tags
  # for each tagging, check if a tag with that text already exists
  # if one does, delete that tagging and add the existing tag
  # tag_ids_to_add = []
  # taggings.each do |tagging|
  #   tag = tagging.tag
  #   # ensure string comparison is case insensitive
  #   existing_tag = Tag.where('lower(text) = ?', tag.text.downcase).first
  #   next if existing_tag.blank?

  #   # remove the tag association, otherwise it tries to create the tag and fails (as the tag already exists)
  #   tags.each do |audio_event_tag|
  #     # The collection.delete method removes one or more objects from the collection by setting their foreign keys to NULL.
  #     # ensure string comparison is case insensitive
  #     tags.delete(audio_event_tag) if existing_tag.text.downcase == audio_event_tag.text.downcase
  #   end

  #   # remove the tagging association
  #   taggings.delete(tagging)

  #   # record the tag id
  #   tag_ids_to_add.push(existing_tag.id)
  # end

  # # add the tagging using the existing tag id
  # tag_ids_to_add.each do |tag_id|
  #   current = Tagging.new(tag_id: tag_id)
  #   taggings << current
  # end
  #end

  def self.function_datetime_timezone(function_name, value1, interval, value2)
    Arel::Nodes::NamedFunction.new(
      function_name,
      [
        infix_operation(:+, value1, interval),
        value2
      ]
    )
  end

  def self.infix_operation(operation, value1, value2)
    Arel::Nodes::InfixOperation.new(operation, value1, value2)
  end

  # Construct verification summary, aggregated by audio event and tag, returned
  # as a common table expression.
  # @return [Array<Arel::Table, Arel::Nodes::As>]
  def self.verification_summary_cte
    verifications = Verification.arel_table
    tags = Tag.arel_table

    verification_tags_agg = Arel::Nodes::SqlLiteral.new(
      'string_agg(CAST("verification_table"."tag_id" as varchar) || \':\' || "tag_text", \'|\')'
    ).as('verifications')
    verification_decisions_agg = Arel::Nodes::SqlLiteral.new(
       'string_agg("verification_table"."verification_decisions", \'|\')'
     ).as('verification_decisions')
    verification_consensus_agg = Arel::Nodes::SqlLiteral.new(
      'string_agg(CAST("verification_table"."verification_consensus" as varchar), \'|\')'
    ).as('verification_consensus')
    verification_count_agg = Arel::Nodes::SqlLiteral.new(
      'string_agg(CAST("verification_table"."verification_counts" as varchar), \'|\')'
    ).as('verification_counts')
    verification_correct_agg = Arel::Nodes::SqlLiteral.new(
       'string_agg(CAST("verification_table"."verification_correct" as varchar), \'|\')'
     ).as('verification_correct')
    verification_incorrect_agg = Arel::Nodes::SqlLiteral.new(
       'string_agg(CAST("verification_table"."verification_incorrect" as varchar), \'|\')'
     ).as('verification_incorrect')
    verification_unsure_agg = Arel::Nodes::SqlLiteral.new(
       'string_agg(CAST("verification_table"."verification_unsure" as varchar), \'|\')'
     ).as('verification_unsure')
    verification_skip_agg = Arel::Nodes::SqlLiteral.new(
       'string_agg(CAST("verification_table"."verification_skip" as varchar), \'|\')'
     ).as('verification_skip')

    verification_subquery = verifications
      .join(tags).on(verifications[:tag_id].eq(tags[:id]))
      .group(verifications[:audio_event_id], verifications[:tag_id], tags[:text])
      .project(
        verifications[:audio_event_id],
        verifications[:tag_id],
        tags[:text].as('tag_text'),
        verifications[:confirmed].count.as('verification_counts'),
        Arel.star.count.filter(verifications[:confirmed].eq(Verification::CONFIRMATION_TRUE)).as('verification_correct'),
        Arel.star.count.filter(verifications[:confirmed].eq(Verification::CONFIRMATION_FALSE)).as('verification_incorrect'),
        Arel.star.count.filter(verifications[:confirmed].eq(Verification::CONFIRMATION_SKIP)).as('verification_skip'),
        Arel.star.count.filter(verifications[:confirmed].eq(Verification::CONFIRMATION_UNSURE)).as('verification_unsure')
      )
      .as('verification_subquery')

    verification_table_alias = Arel::Table.new(:verification_subquery)

    greatest_function = Arel::Nodes::NamedFunction.new('GREATEST', [
      verification_table_alias[:verification_correct],
      verification_table_alias[:verification_incorrect],
      verification_table_alias[:verification_skip],
      verification_table_alias[:verification_unsure]
    ])

    verification_consensus = (greatest_function / verification_table_alias[:verification_counts].cast('numeric'))

    which_max = Arel.sql(
            <<~SQL.squish
              (
              SELECT label
               FROM (VALUES
                   ('correct', verification_subquery.verification_correct),
                   ('incorrect', verification_subquery.verification_incorrect),
                   ('skip', verification_subquery.verification_skip),
                   ('unsure', verification_subquery.verification_unsure)
               ) AS v(label, count)
               ORDER BY count DESC
               LIMIT 1
               )
            SQL
          )

    verification_outer_query = Arel::SelectManager.new
      .from(verification_subquery)
      .project(
        verification_table_alias[Arel.star],
        which_max.as('verification_decisions'),
        verification_consensus.round(2).as('verification_consensus')
      )
      .as('verification_table')

    verification_table = Arel::Table.new(:verification_table)

    verification_select = Arel::SelectManager.new
      .from(verification_outer_query)
      .group(verification_table[:audio_event_id])
      .project(
        verification_table[:audio_event_id],
        verification_tags_agg,
        verification_count_agg,
        verification_correct_agg,
        verification_incorrect_agg,
        verification_skip_agg,
        verification_unsure_agg,
        verification_decisions_agg,
        verification_consensus_agg
      )

    verification_cte_table = Arel::Table.new(:verification_cte_table)
    verification_cte = Arel::Nodes::As.new(verification_cte_table, verification_select)
    [verification_cte_table, verification_cte]
  end
end
