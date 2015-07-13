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
        text_fields: [],
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
  # @return [ActiveRecord::Relation] query
  def build_query(user)
    fail ArgumentError, 'Cannot execute the query without a user instance.' if user.blank?

    filter_query = Filter::Query.new(
        { filter: stored_query },
        Access::Query.audio_recordings(user, Access::Core.levels_allow),
        AudioRecording,
        AudioRecording.filter_settings)

    query = filter_query.build.build_exists(Site.arel_table, Project.arel_table, nil, {}, false).project(:id)
    query = AudioRecording.arel_table.join(Site.arel_table).on(AudioRecording.arel_table[:site_id].eq(query))
    Rails.logger.warn query.to_sql

    init_query = filter_query.initial_query
    filter_query.query_filter(init_query)
  end

  # Execute filter built from the stored query.
  # @param [User] user
  # @return [AudioRecording::ActiveRecord_Relation] audio recordings
  def execute_query(user)
    query = build_query(user)

    # return an array of audio recordings with no select specified
    query.except(:select)
  end

  # Get the projects used by the filter in the stored query.
  # @param [User] user
  # @return [Project::ActiveRecord_Relation] projects
  def extract_projects(user)
    query = build_query(user)


   # select * from projects where project id in (select projects.id from projects inner join sites, audio_recordings where audio_recording_id in )
    sub_query_audio_recording_ids = query.pluck(:id)

    sub_query_project_ids = Project
                                .joins(sites: [:audio_recordings])
                                .where(audio_recordings: {id: sub_query_audio_recording_ids})
                                .pluck(:id)


    # return the projects used in the filter
    Project.where(id: sub_query_project_ids)
  end

  # Populate the projects used by the filter in the stored query.
  # @param [User] user
  # @return [void]
  def populate_projects(user)
    self.projects = extract_projects(user)
    self.save!
  end

end