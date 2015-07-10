class SavedSearch < ActiveRecord::Base

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_saved_searches
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_saved_searches

  has_and_belongs_to_many :projects, inverse_of: :saved_searches
  has_many :analysis_jobs, inverse_of: :saved_search

  # Serialize stored_query using JSON as coder.
  serialize :stored_query, JSON

  validates :name, presence: true, length: { minimum: 2, maximum: 255 }, uniqueness: { case_sensitive: false }
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
                on: Site.arel_table[:id].eq(Arel::Table.new(:projects_saved_searches)[:saved_search_id]),
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
end