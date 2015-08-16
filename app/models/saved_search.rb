class SavedSearch < ActiveRecord::Base

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_saved_searches
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_saved_searches

  has_and_belongs_to_many :projects, inverse_of: :saved_searches
  has_many :analysis_jobs, inverse_of: :saved_search

  # Serialize stored_query using JSON as coder.
  # this is a filter query for audio recordings.
  serialize :stored_query, JSON

  validates :name, presence: true, length: { minimum: 2, maximum: 255 },
            uniqueness: {case_sensitive: false, scope: :creator_id, message: 'should be unique per user'}
  validates :stored_query, presence: true

  def self.filter_settings
    {
        valid_fields: [:id, :name, :description, :stored_query,:created_at, :creator_id],
        render_fields: [:id, :name, :description, :stored_query,:created_at, :creator_id],
        text_fields: [:name, :description],
        custom_fields: lambda { |saved_search, user|
          saved_search_hash = {}

          saved_search_hash[:project_ids] = SavedSearch.find(saved_search.id).projects.pluck(:id)
          saved_search_hash[:analysis_job_ids] = SavedSearch.find(saved_search.id).analysis_jobs.pluck(:id)

          [saved_search, saved_search_hash]
        },
        controller: :saved_searches,
        action: :filter,
        defaults: {
            order_by: :name,
            direction: :asc
        },
        field_mappings: [],
        valid_associations: [
            {
                join: AnalysisJob,
                on: AnalysisJob.arel_table[:saved_search_id].eq(SavedSearch.arel_table[:id]),
                available: true
            },
            {
                join: Arel::Table.new(:projects_saved_searches),
                on: SavedSearch.arel_table[:id].eq(Arel::Table.new(:projects_saved_searches)[:saved_search_id]),
                available: false,
                associations: [
                    {
                        join: Project,
                        on: Arel::Table.new(:projects_saved_searches)[:project_id].eq(Project.arel_table[:id]),
                        available: true
                    }
                ]

            }
        ]
    }
  end

  # Build filter from the stored query.
  # @param [User] user
  # @return [Arel::Nodes::Node, Array<Arel::Nodes::Node>]
  def audio_recording_filter(user)
    user = Access::Core.validate_user(user)

    filter_query = Filter::Query.new(
        { filter: stored_query },
        Access::Query.audio_recordings(user, Access::Core.levels_allow),
        AudioRecording,
        AudioRecording.filter_settings)

    # debugging
    # query = filter_query.build.build_exists(Site.arel_table, Project.arel_table, nil, {}, false).project(:id)
    # query = AudioRecording.arel_table.join(Site.arel_table).on(AudioRecording.arel_table[:site_id].eq(query))
    # Rails.logger.warn query.to_sql

    # Get parsed filter in Arel form
    parsed_filter = filter_query.filter

    filter_query.build.parse(parsed_filter)
  end

  # Execute filter built from the stored query.
  # @param [User] user
  # @return [Arel::SelectManager] audio recordings
  def extract_audio_recordings(user)
    user = Access::Core.validate_user(user)

    where_clause = audio_recording_filter(user)

    ar = AudioRecording.arel_table

    # return audio recording query with no select specified
    ar.where(where_clause)
  end

  # Get the projects used by the filter in the stored query.
  # @param [User] user
  # @return [Arel::SelectManager] projects
  def extract_projects(user)
    user = Access::Core.validate_user(user)

    where_clause = audio_recording_filter(user)

    pt = Project.arel_table
    ps = Arel::Table.new(:projects_sites)
    ar = AudioRecording.arel_table

=begin
SELECT *
FROM projects
WHERE EXISTS (
  SELECT 1
  FROM projects_sites
  WHERE
    "projects"."id" = "projects_sites"."project_id"
    AND EXISTS (
      SELECT 1
      FROM "audio_recordings"
      WHERE
        "projects_sites"."site_id" = "audio_recordings"."site_id"
        AND <where clause built from audio recording filter>
    )
  )
=end

    audio_recordings_exists =
        ar
            .where(pt[:deleted_at].eq(nil))
            .where(ar[:site_id].eq(ps[:site_id]))
            .where(where_clause)
            .project(1)
            .exists

    projects_sites_exist =
        ps
            .where(pt[:id].eq(ps[:project_id]))
            .where(audio_recordings_exists)
            .project(1)
            .exists

    pt.where(projects_sites_exist)
  end

  # Populate the projects used by the filter in the stored query.
  # @param [User] user
  # @return [void]
  def populate_projects(user)
    project_query = extract_projects(user)
    self.projects = project_query.to_a
    self.save!
  end

end