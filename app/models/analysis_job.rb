# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_jobs
#
#  id                                                                                                                                                                                      :integer          not null, primary key
#  amend_count(Count of amendments)                                                                                                                                                        :integer          default(0), not null
#  deleted_at                                                                                                                                                                              :datetime
#  description                                                                                                                                                                             :text
#  filter(API filter to include recordings in this job. If blank then all recordings are included.)                                                                                        :jsonb
#  name                                                                                                                                                                                    :string           not null
#  ongoing(If true the filter for this job will be evaluated after a harvest. If more items are found the job will move to the processing stage if needed and process the new recordings.) :boolean          default(FALSE), not null
#  overall_count                                                                                                                                                                           :integer          not null
#  overall_data_length_bytes                                                                                                                                                               :bigint           default(0), not null
#  overall_duration_seconds                                                                                                                                                                :float            not null
#  overall_status                                                                                                                                                                          :string           not null
#  overall_status_modified_at                                                                                                                                                              :datetime         not null
#  resume_count(Count of resumptions)                                                                                                                                                      :integer          default(0), not null
#  retry_count(Count of retries)                                                                                                                                                           :integer          default(0), not null
#  started_at                                                                                                                                                                              :datetime
#  suspend_count(Count of suspensions)                                                                                                                                                     :integer          default(0), not null
#  system_job(If true this job is automatically run and not associated with a single project. We can have multiple system jobs.)                                                           :boolean          default(FALSE), not null
#  created_at                                                                                                                                                                              :datetime
#  updated_at                                                                                                                                                                              :datetime
#  creator_id                                                                                                                                                                              :integer          not null
#  deleter_id                                                                                                                                                                              :integer
#  project_id(Project this job is associated with. This field simply influences which jobs are shown on a project page.)                                                                   :integer
#  updater_id                                                                                                                                                                              :integer
#
# Indexes
#
#  analysis_jobs_name_uidx            (name,creator_id) UNIQUE
#  index_analysis_jobs_on_creator_id  (creator_id)
#  index_analysis_jobs_on_deleter_id  (deleter_id)
#  index_analysis_jobs_on_project_id  (project_id)
#  index_analysis_jobs_on_updater_id  (updater_id)
#
# Foreign Keys
#
#  analysis_jobs_creator_id_fk  (creator_id => users.id)
#  analysis_jobs_deleter_id_fk  (deleter_id => users.id)
#  analysis_jobs_updater_id_fk  (updater_id => users.id)
#  fk_rails_...                 (project_id => projects.id) ON DELETE => cascade
#
class AnalysisJob < ApplicationRecord
  # add the state machine
  include StateMachine

  # job status values
  AVAILABLE_JOB_STATUS_SYMBOLS = aasm.states.map(&:name)
  AVAILABLE_JOB_STATUS = AVAILABLE_JOB_STATUS_SYMBOLS.map(&:to_s)

  AVAILABLE_JOB_STATUS_DISPLAY = aasm.states.to_h { |x| [x.name, x.display_name] }

  ALLOWED_USER_TRANSITIONS = [
    :retry,
    :resume,
    :suspend,
    :amend
  ].freeze

  SYSTEM_JOB_NAME = 'default'
  SYSTEM_JOB_ID = 'system'

  belongs_to :creator, class_name: 'User', inverse_of: :created_analysis_jobs
  belongs_to :updater, class_name: 'User', inverse_of: :updated_analysis_jobs,
    optional: true
  belongs_to :deleter, class_name: 'User', inverse_of: :deleted_analysis_jobs,
    optional: true

  belongs_to :project, inverse_of: :analysis_jobs, optional: true

  has_many :analysis_jobs_scripts, dependent: :delete_all
  has_many :scripts, through: :analysis_jobs_scripts, inverse_of: :analysis_jobs

  has_many :analysis_jobs_items, inverse_of: :analysis_job, dependent: :delete_all
  has_many :audio_event_imports, inverse_of: :analysis_job, dependent: :destroy

  # add deleted_at and deleter_id
  acts_as_discardable
  also_discards :audio_event_imports, batch: true

  # attribute validations
  validates :name, presence: true, length: { minimum: 2, maximum: 255 }
  validates :name, uniqueness: {
    scope: :creator_id,
    case_sensitive: false,
    message: 'each job creator user must have unique job names'
  }

  # overall_count is the number of audio_recordings/resque jobs. These should be equal.
  validates :overall_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :overall_duration_seconds, presence: true,
    numericality: { only_integer: false, greater_than_or_equal_to: 0 }
  validates :started_at, allow_blank: true, timeliness: {
    on_or_before: -> { Time.zone.now }, type: :datetime
  }
  validates :overall_data_length_bytes, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validates :analysis_jobs_scripts, presence: true

  validate :filter_hash_is_valid

  validate :project_id_set_for_non_system_jobs

  #
  # scopes
  #

  scope :system_analyses, -> { where(system_job: true).order(created_at: :desc) }
  scope :ongoing, -> { where(ongoing: true) }
  scope :not_completed, -> { where.not(overall_status: 'completed') }

  # Return the latest system Analysis Job ID
  # @return [Integer,nil] nil if not found
  def self.latest_system_analysis_id
    AnalysisJob.system_analyses.pick(:id)
  end

  # @return [AnalysisJob,nil] return the latest system analysis if found
  def self.latest_system_analysis
    AnalysisJob.system_analyses.first
  end

  # @return [AnalysisJob] return the latest system analysis or raises an error if not found
  def self.latest_system_analysis!
    AnalysisJob.system_analyses.first!
  end

  def self.build_system_job(owner)
    # copy previous system job scripts
    scripts = latest_system_analysis&.scripts || []

    AnalysisJob.new(
      name: SYSTEM_JOB_NAME,
      description: 'A default analysis run on all audio',
      creator: owner,
      # don't know which ones should be added by default
      scripts:,
      system_job: true,
      ongoing: true,
      # i.e. all recordings
      filter: nil
    )
  end

  def self.arel_script_ids
    aj = AnalysisJob.arel_table
    ajs = Arel::Table.new(:analysis_jobs_scripts)

    Arel::Nodes::NamedFunction.new(
      'array',
      [
        ajs
        # select script_id
        # from analysis_jobs_scripts
        .project(ajs[:script_id])
        # where analysis_job_id = analysis_jobs.id
        .where(aj[:id].eq(ajs[:analysis_job_id]))
        # order by script_id asc
        .order(ajs[:script_id].asc)
      ]
    )
  end

  def self.audio_event_import_ids
    aj = AnalysisJob.arel_table
    aei = AudioEventImport.arel_table

    Arel::Nodes::NamedFunction.new(
      'array',
      [
        aei
        # select audio_event_import_id
        # from audio_event_imports
        .project(aei[:id])
        # where analysis_job_id = analysis_jobs.id
        .where(aj[:id].eq(aei[:analysis_job_id]))
        # order by audio_event_import_id asc
        .order(aei[:id].asc)
      ]
    )
  end

  renders_markdown_for :description

  def self.filter_settings
    fields = [
      :id, :name, :description,
      :creator_id, :updater_id, :deleter_id,
      :created_at, :updated_at, :deleted_at,
      :filter, :system_job, :ongoing, :project_id,
      :retry_count, :amend_count, :suspend_count,
      :started_at,
      :overall_status, :overall_status_modified_at,
      :overall_progress, :script_ids, :audio_event_import_ids,
      :overall_count, :overall_duration_seconds, :overall_data_length_bytes
    ]

    {
      valid_fields: fields,
      render_fields: fields + [:description_html_tagline, :description_html],
      text_fields: [:name, :description],
      custom_fields2: {
        **AnalysisJob.new_render_markdown_for_api_for(:description),
        script_ids: {
          query_attributes: [],
          transform: nil,
          arel: arel_script_ids,
          type: :array
        },
        # history: this used to be a field we stored in the database because
        # we didn't actually track analysis jobs items - we just sprayed all
        # jobs at the remote queue and hoped for the best. Now we track items
        # so now storing the progress is redundant (and a pain to maintain because
        # it represents a cached value that can become stale).
        overall_progress: {
          query_attributes: [],
          transform: nil,
          arel: job_progress_arel,
          type: :hash
        },
        audio_event_import_ids: {
          query_attributes: [],
          transform: nil,
          arel: audio_event_import_ids,
          type: :array
        }
      },
      new_spec_fields: lambda { |_user|
                         {
                           name: nil,
                           description: nil,
                           project_id: nil,
                           system_job: false,
                           ongoing: false,
                           scripts: [],
                           filter: {}
                         }
                       },
      controller: :audio_events,
      action: :filter,
      defaults: {
        order_by: :updated_at,
        direction: :desc
      },
      valid_associations: [
        {
          join: Arel::Table.new(:analysis_jobs_scripts),
          on: AnalysisJob.arel_table[:id].eq(Arel::Table.new(:analysis_jobs_scripts)[:analysis_job_id]),
          available: false,
          associations: [
            {
              join: Script,
              on: Arel::Table.new(:analysis_jobs_scripts)[:script_id].eq(Script.arel_table[:id]),
              available: true
            }
          ]
        },
        {
          join: Project,
          on: AnalysisJob.arel_table[:project_id].eq(Project.arel_table[:id]),
          available: true
        }
      ]
    }
  end

  def self.schema
    progress_properties = [
      :status_new_count,
      :status_queued_count,
      :status_working_count,
      :status_finished_count,
      :transition_empty_count,
      :transition_queue_count,
      :transition_cancel_count,
      :transition_retry_count,
      :transition_finish_count,
      :result_empty_count,
      :result_success_count,
      :result_failed_count,
      :result_killed_count,
      :result_cancelled_count
    ].index_with { |_| { type: 'integer', readOnly: true } }

    {
      type: 'object',
      additionalProperties: false,
      properties: {
        id: Api::Schema.id,
        name: { type: 'string' },
        **Api::Schema.rendered_markdown(:description),
        filter: { type: 'object' },
        system_job: { type: 'boolean' },
        ongoing: { type: 'boolean' },
        project_id: Api::Schema.id(nullable: true),
        retry_count: { type: 'integer', readOnly: true },
        amend_count: { type: 'integer', readOnly: true },
        suspend_count: { type: 'integer', readOnly: true },
        started_at: { type: ['null', 'date'], readOnly: true },
        overall_status: { type: 'string', enum: [
          :preparing,
          :processing,
          :completed,
          :suspended
        ], readOnly: true },
        overall_status_modified_at: { type: ['null', 'date'], readOnly: true },
        overall_progress: {
          type: 'object',
          properties: progress_properties,
          readOnly: true
        },
        overall_count: { type: 'integer', readOnly: true },
        overall_duration_seconds: { type: 'number', readOnly: true },
        overall_data_length_bytes: { type: 'integer', readOnly: true },
        **Api::Schema.all_user_stamps,
        script_ids: Api::Schema.ids(read_only: true),
        audio_event_import_ids: Api::Schema.ids(read_only: true),
        transition: {
          type: 'string',
          enum: ALLOWED_USER_TRANSITIONS,
          writeOnly: true
        }
      },
      required: [
        :id,
        :name,
        :description,
        :description_html,
        :description_html_tagline,
        :filter,
        :system_job,
        :ongoing,
        :retry_count,
        :amend_count,
        :suspend_count,
        :started_at,
        :overall_status,
        :overall_status_modified_at,
        # not required because https://github.com/QutEcoacoustics/baw-server/issues/691
        #:overall_progress,
        #:script_ids,
        :overall_count,
        :overall_duration_seconds,
        :overall_data_length_bytes
      ]
    }.freeze
  end

  #
  # public methods
  #

  def system_job?
    !!system_job
  end

  def ongoing?
    !!ongoing
  end

  # Transforms a filter hash (of the format of the API filter objects)
  # to an Arel. The result is an Arel object that returns the ids of
  # the audio recordings that match the filter.
  #
  # The Arel expression includes a permissions check: only records that match
  # the filter AND that the creator of this analysis job has access to will be
  # returned.
  # @return [ActiveRecord::Relation]
  def filter_as_relation
    # we assume the filter stored is just the conditional filter hash
    whole_filter = {
      projection: {
        include: [:id]
      },
      filter:
    }

    # do not allow results wider than the selected project if this job
    # is associated with a project.
    # Conversely, if a system job, then allow access to everything.
    if system_job?
      raise 'system jobs cannot have a project id' if project_id.present?

      AudioRecording.all
    else
      raise 'project id required' if project_id.blank?

      # only allow the recordings the creator has *write* access to be returned
      # - this is because importing results will create new audio events
      # which is what the writer permission is for.
      Access::ByPermission.audio_recordings(
        creator,
        levels: Access::Permission::WRITER_OR_ABOVE,
        project_ids: [project_id]
      )
    end => base_scope

    # never allow non-ready recordings to be included in the filter
    base_scope = base_scope.status_ready

    # additionally, since we enforce the ready check in the scope, we don't
    # need to duplicate the condition that comes from the filter defaults
    filter_settings = AudioRecording.filter_settings.dup
    filter_settings[:defaults].delete(:filter)

    filter_query = Filter::Query.new(
      whole_filter,
      base_scope,
      AudioRecording,
      filter_settings
    )

    filter_query.query_without_paging_sorting
  end

  # Queries current analysis jobs items and returns a hash of statistics for the
  # associated recordings.
  # @return [Hash<Symbol, Numeric>]
  def overall_statistics_query
    AudioRecording
      .joins(
        AudioRecording.arel_table.join(
          AnalysisJobsItem
            .arel_table
            .where(AnalysisJobsItem.arel_table[:analysis_job_id].eq(id))
            .project(AnalysisJobsItem.arel_table[:audio_recording_id])
            .distinct
            .as(AnalysisJobsItem.table_name)
        )
        .on(AudioRecording.arel_table[:id].eq(AnalysisJobsItem.arel_table[:audio_recording_id]))
        .join_sources
      )
      .pick_hash({
        overall_count: Arel.star.count.coalesce(0),
        overall_duration_seconds:
          AudioRecording.arel_table[:duration_seconds].cast(:float).sum.coalesce(0),
        overall_data_length_bytes:
          AudioRecording.arel_table[:data_length_bytes].cast('bigint').sum.coalesce(0)
      })
  end

  # Returns a arel grouping containing a postgres json object containing
  # counts of the status, transition, and result of the analysis jobs items.
  # @return [Arel::Nodes::Grouping]
  def self.job_progress_arel
    analysis_job = AnalysisJob.arel_table
    items = AnalysisJobsItem.arel_table

    [
      ['status', AnalysisJobsItem::AVAILABLE_ITEM_STATUS],
      ['transition', [nil, *AnalysisJobsItem::ALLOWED_TRANSITIONS]],
      ['result', [nil, *AnalysisJobsItem::ALLOWED_RESULTS]]
    ].flat_map { |(column, values)|
      values.map do |value|
        key = "#{column}_#{value || 'empty'}_count"
        [key, Arel.star.count.filter(items[column].eq(value))]
      end
    }.to_h => key_value_pairs

    items
      .project(
        Arel.json(key_value_pairs).as('overall_progress')
      ).where(
        items[:analysis_job_id].eq(analysis_job[:id])
      ) => result

    # return Arel::Nodes::SelectStatement rather than a Arel::SelectManager
    Arel::Nodes::Grouping.new(result.ast)
  end

  # Returns a hash of statistics for the analysis jobs items in an analysis job.
  # Counts of status, result, and transition are returned.
  # @return [Hash<Symbol, Numeric>]
  def job_progress_query
    self.class
      .pick(self.class.job_progress_arel)
      .transform_keys(&:to_sym)
  end

  # Intended to be called when we know a change in status has happened -
  # i.e. when an analysis_jobs_item status has changed.
  def check_progress!
    # finally, after each update, check if we can finally finish the job!
    complete! if may_complete?
  end

  #
  # other methods
  #

  private

  # system jobs are part of a chain of system run jobs. The special 'SYSTEM' token
  # resolves to the latest result set of any of the system jobs.
  # Thus it does not make sense for a project scoped job to be a system job...
  # Since it isn't a) system wide or b) part of a chain of system jobs.
  def project_id_set_for_non_system_jobs
    # effectively xor: only one or the other can be true
    return if system_job? ^ project_id.present?

    errors.add(:project_id, 'must be blank for system jobs') if system_job?
    errors.add(:system_job, 'must be true if project_id is blank') if project_id.blank?
  end

  def filter_hash_is_valid
    return if filter.blank?

    unless filter.is_a?(Hash)
      errors.add(:filter, 'must be a hash')
      return
    end

    outer_keys = [:filter, :projection, :paging, :sorting]

    if filter.keys.map(&:to_sym).intersect?(outer_keys)
      keys = outer_keys.map(&:to_s).join(', ')
      errors.add(:filter, "must be an inner filter, cannot contain any of #{keys}")
      return
    end

    # check the filter is valid
    begin
      # to sql avoid execution of the actual query but still allows our filter
      # query construction to run and check for valid syntax
      filter_as_relation.to_sql
    rescue StandardError => e
      errors.add(:filter, e.message.to_s)
    end
  end
end
