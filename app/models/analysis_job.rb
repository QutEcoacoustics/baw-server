class AnalysisJob < ActiveRecord::Base

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_analysis_jobs
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_analysis_jobs
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_analysis_jobs

  belongs_to :script, inverse_of: :analysis_jobs
  belongs_to :saved_search, inverse_of: :analysis_jobs
  has_many :projects, through: :saved_searches

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # association validations
  validates :script, existence: true
  validates :saved_search, existence: true
  validates :creator, existence: true

  # attribute validations
  validates :name, presence: true, length: {minimum: 2, maximum: 255}, uniqueness: {case_sensitive: false}
  validates :script_settings, presence: true

  # job status values - completed just means all processing has finished, whether it succeeds or not.
  AVAILABLE_JOB_STATUS_SYMBOLS = [:new, :preparing, :processing, :suspended, :completed]
  AVAILABLE_JOB_STATUS = AVAILABLE_JOB_STATUS_SYMBOLS.map { |item| item.to_s }

  AVAILABLE_JOB_STATUS_DISPLAY = [
      {id: :new, name: 'New'},
      {id: :preparing, name: 'Preparing'},
      {id: :processing, name: 'Processing'},
      {id: :suspended, name: 'Suspended'},
      {id: :completed, name: 'Completed'},
  ]

  enumerize :job_status, in: AVAILABLE_JOB_STATUS, predicates: true

  def self.filter_settings
    {
        valid_fields: [:id, :name, :description, :created_at, :creator_id, :updated_at, :updater_id],
        render_fields: [:id, :name, :description, :created_at, :creator_id, :updated_at, :updater_id],
        text_fields: [],
        custom_fields: lambda { |analysis_job, user|
          analysis_job_hash = {}

          analysis_job_hash[:saved_search] =
              SavedSearch
                  .where(id: analysis_job.saved_search_id)
                  .pluck(*SavedSearch.filter_settings[:render_fields])
                  .first
          analysis_job_hash[:script] =
              Script
                  .where(id: analysis_job.script_id)
                  .pluck(*Script.filter_settings[:render_fields])
                  .first

          [analysis_job, analysis_job_hash]
        },
        controller: :audio_events,
        action: :filter,
        defaults: {
            order_by: :name,
            direction: :asc
        },
        field_mappings: [],
        valid_associations: [
            {
                join: SavedSearch,
                on: AnalysisJob.arel_table[:saved_search_id].eq(SavedSearch.arel_table[:id]),
                available: true
            },
            {
                join: Script,
                on: AnalysisJob.arel_table[:script_id].eq(Script.arel_table[:id]),
                available: true
            }
        ]
    }
  end
end
