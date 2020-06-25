# frozen_string_literal: true

class SavedSearch < ApplicationRecord
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_saved_searches
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_saved_searches, optional: true

  has_and_belongs_to_many :projects, inverse_of: :saved_searches
  has_many :analysis_jobs, inverse_of: :saved_search

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  validates :name, presence: true, length: { minimum: 2, maximum: 255 },
                   uniqueness: { case_sensitive: false, scope: :creator_id, message: 'should be unique per user' }
  validates :stored_query, presence: true

  validate :has_projects

  def self.filter_settings
    {
      valid_fields: [:id, :name, :description, :stored_query, :created_at, :creator_id],
      render_fields: [:id, :name, :description, :stored_query, :created_at, :creator_id],
      text_fields: [:name, :description],
      custom_fields: lambda { |item, _user|
                       # do a query for the attributes that may not be in the projection
                       # instance or id can be nil
                       fresh_saved_search = item.nil? || item.id.nil? ? nil : SavedSearch.find(item.id)

                       saved_search_hash = {}

                       saved_search_hash[:project_ids] = fresh_saved_search.nil? ? nil : fresh_saved_search.projects.pluck(:id).flatten
                       saved_search_hash[:analysis_job_ids] = fresh_saved_search.nil? ? nil : fresh_saved_search.analysis_jobs.pluck(:id).flatten

                       [item, saved_search_hash]
                     },
      controller: :saved_searches,
      action: :filter,
      defaults: {
        order_by: :created_at,
        direction: :desc
      },
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

  # Build Arel conditions from stored_query.
  # @param [User] user
  # @return [Arel::Nodes::Node, Array<Arel::Nodes::Node>] conditions
  def audio_recording_conditions(user)
    user = Access::Validate.user(user)

    filter_query = Filter::Query.new(
      { filter: stored_query },
      Access::ByPermission.audio_recordings(user),
      AudioRecording,
      AudioRecording.filter_settings
    )

    # parse filter from params
    parsed_filter = filter_query.filter

    # Get parsed filter conditions in Arel form
    filter_query.build.parse(parsed_filter)
  end

  # Execute filter built from the stored query.
  # @param [User] user
  # @return [ActiveRecord::Relation] audio recordings
  def audio_recordings_extract(user)
    user = Access::Validate.user(user)

    conditions = audio_recording_conditions(user)

    # add conditions to ActiveRecord AudioRecording query
    append_conditions(AudioRecording.all, conditions)
  end

  # Get the projects used by the filter in the stored query.
  # @param [User] user
  # @return [ActiveRecord::Relation] projects
  def projects_extract(user)
    user = Access::Validate.user(user)

    pt = Project.arel_table
    ps = Arel::Table.new(:projects_sites)
    ar = AudioRecording.arel_table

    # SELECT *
    # FROM projects
    # WHERE EXISTS (
    #   SELECT 1
    #   FROM projects_sites
    #   WHERE
    #     "projects"."id" = "projects_sites"."project_id"
    #     AND EXISTS (
    #       SELECT 1
    #       FROM "audio_recordings"
    #       WHERE
    #         "projects_sites"."site_id" = "audio_recordings"."site_id"
    #         AND <where clause built from audio recording filter>
    #     )
    #   )

    audio_recordings_exists =
      ar
      .where(pt[:deleted_at].eq(nil))
      .where(ar[:site_id].eq(ps[:site_id]))

    conditions = audio_recording_conditions(user)
    audio_recordings_exists = append_conditions(audio_recordings_exists, conditions)

    audio_recordings_exists =
      audio_recordings_exists
      .project(1)
      .exists

    projects_sites_exist =
      ps
      .where(pt[:id].eq(ps[:project_id]))
      .where(audio_recordings_exists)
      .project(1)
      .exists

    Project.where(projects_sites_exist)
  end

  # Populate the projects used by the filter in the stored query.
  # @param [User] user
  # @return [void]
  def projects_populate(user)
    # TODO: add logging and timing
    # TODO This may need to be async depending on how fast it runs

    user = Access::Validate.user(user)
    project_query = projects_extract(user)
    self.projects = project_query
  end

  private

  def append_conditions(query, conditions)
    conditions.each do |condition|
      query = query.where(condition)
    end
    query
  end

  def has_projects; end
end
