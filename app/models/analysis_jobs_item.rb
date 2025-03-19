# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_jobs_items
#
#  id                                                                                                                                                            :bigint           not null, primary key
#  attempts(Number of times this job item has been attempted)                                                                                                    :integer          default(0), not null
#  cancel_started_at                                                                                                                                             :datetime
#  error(Error message if this job item failed)                                                                                                                  :text
#  finished_at                                                                                                                                                   :datetime
#  import_success(Did importing audio events succeed?)                                                                                                           :boolean
#  queued_at                                                                                                                                                     :datetime
#  result(Result of this job item)                                                                                                                               :enum
#  status(Current status of this job item)                                                                                                                       :enum             default("new"), not null
#  transition(The pending transition to apply to this item. Any high-latency action should be done via transition and on a worker rather than in a web request.) :enum
#  used_memory_bytes(Memory used by this job item)                                                                                                               :integer
#  used_walltime_seconds(Walltime used by this job item)                                                                                                         :integer
#  work_started_at                                                                                                                                               :datetime
#  created_at                                                                                                                                                    :datetime         not null
#  analysis_job_id                                                                                                                                               :integer          not null
#  audio_recording_id                                                                                                                                            :integer          not null
#  queue_id                                                                                                                                                      :string(255)
#  script_id(Script used for this item)                                                                                                                          :integer          not null
#
# Indexes
#
#  index_analysis_jobs_items_are_unique             (analysis_job_id,script_id,audio_recording_id) UNIQUE
#  index_analysis_jobs_items_on_analysis_job_id     (analysis_job_id)
#  index_analysis_jobs_items_on_audio_recording_id  (audio_recording_id)
#  index_analysis_jobs_items_on_script_id           (script_id)
#  queue_id_uidx                                    (queue_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (analysis_job_id => analysis_jobs.id) ON DELETE => cascade
#  fk_rails_...  (audio_recording_id => audio_recordings.id) ON DELETE => cascade
#  fk_rails_...  (script_id => scripts.id)
#
class AnalysisJobsItem < ApplicationRecord
  extend Enumerize
  extend BulkQueries
  include ImportResults

  # add the state machine
  include StateMachine

  # item status values - timed out is a special failure case where the worker never reports back

  AVAILABLE_ITEM_STATUS_SYMBOLS = aasm.states.map(&:name)
  AVAILABLE_ITEM_STATUS = AVAILABLE_ITEM_STATUS_SYMBOLS.map(&:to_s)

  AVAILABLE_ITEM_STATUS_DISPLAY = aasm.states.to_h { |x| [x.name, x.display_name] }
  WORKING_STATUS_SYMBOLS = [STATUS_QUEUED, STATUS_WORKING].freeze
  COMPLETED_ITEM_STATUS_SYMBOLS = [STATUS_FINISHED].freeze

  has_many :audio_event_import_files, inverse_of: :analysis_jobs_item, dependent: :destroy

  # ensure we allow with_discarded here for race condition where analysis job
  # has been soft deleted while job items are still updating
  belongs_to :analysis_job, -> { with_discarded }, inverse_of: :analysis_jobs_items
  belongs_to :audio_recording, inverse_of: :analysis_jobs_items
  belongs_to :script, inverse_of: :analysis_jobs_items

  # we use all the following associations to help with filtering for virtual directories

  # attribute validations
  validates :status, presence: true, inclusion: { in: AVAILABLE_ITEM_STATUS }
  validates :queue_id, uniqueness: { case_sensitive: true }, allow_nil: true

  validate :new_when_created, on: :create
  validate :transition_set_when_created, on: :create
  before_validation do
    self.transition = TRANSITION_QUEUE if new_record?
  end
  validate :queue_id_set_when_needed

  validates :created_at,
    presence: true,
    timeliness: { on_or_before: -> { Time.zone.now }, type: :datetime },
    unless: :new_record?

  validates :queued_at, :work_started_at, :finished_at,
    allow_blank: true,
    timeliness: { on_or_before: -> { Time.zone.now }, type: :datetime }

  # so the transitions allowed in this column are the ones that are slow to do
  # i.e. where we must contact the remote queue
  # these transitions are processed by the CancelItemsJob and the RemoteEnqueueJob
  TRANSITION_QUEUE = 'queue'
  TRANSITION_RETRY = 'retry'
  TRANSITION_CANCEL = 'cancel'
  TRANSITION_FINISH = 'finish'
  ALLOWED_TRANSITIONS = [TRANSITION_QUEUE, TRANSITION_CANCEL, TRANSITION_RETRY, TRANSITION_FINISH].freeze
  # @!method transition_queue?
  #   @return [Boolean] true if the item needs to be queued
  # @!method transition_queue!
  #   @return [void]
  # @!method transition_cancel?
  #   @return [Boolean] true if the item needs to be cancelled
  # @!method transition_cancel!
  #   @return [void]
  # @!method transition_retry?
  #   @return [Boolean] true if the item needs to be retried
  # @!method transition_retry!
  #   @return [void]
  # @!method transition_finish?
  #   @return [Boolean] true if the item needs to be finished
  # @!method transition_finish!
  #   @return [void]
  enum :transition, {
    TRANSITION_QUEUE => TRANSITION_QUEUE,
    TRANSITION_CANCEL => TRANSITION_CANCEL,
    TRANSITION_RETRY => TRANSITION_RETRY,
    TRANSITION_FINISH => TRANSITION_FINISH
  }, prefix: :transition

  # @return [Boolean] true if the item needs to transition to happen
  def transition_empty?
    transition.nil?
  end

  RESULT_SUCCESS = 'success'
  RESULT_FAILED = 'failed'
  RESULT_KILLED = 'killed'
  RESULT_CANCELLED = 'cancelled'
  ALLOWED_RESULTS = [RESULT_SUCCESS, RESULT_FAILED, RESULT_KILLED, RESULT_CANCELLED].freeze
  # @!method result_success?
  #   @return [Boolean] true if the item was successful
  # @!method result_success!
  #   @return [void]
  # @!method result_failed?
  #   @return [Boolean] true if the item failed
  # @!method result_failed!
  #   @return [void]
  # @!method result_killed?
  #   @return [Boolean] true if the item was killed
  # @!method result_killed!
  #   @return [void]
  # @!method result_cancelled?
  #   @return [Boolean] true if the item was cancelled
  # @!method result_cancelled!
  #   @return [void]
  enum :result, {
    RESULT_SUCCESS => RESULT_SUCCESS,
    RESULT_FAILED => RESULT_FAILED,
    RESULT_KILLED => RESULT_KILLED,
    RESULT_CANCELLED => RESULT_CANCELLED
  }, prefix: :result

  FAILED_RESULTS = [RESULT_FAILED, RESULT_KILLED, RESULT_CANCELLED].freeze

  def result_empty?
    result.nil?
  end

  def import_success?
    import_success == true
  end

  def import_failed?
    import_success == false
  end

  def import_not_completed?
    import_success.nil?
  end

  # working is a state we can transition to
  # finish is a transition we can request that a worker will process
  ALLOWED_WEB_UPDATES = [STATUS_WORKING.to_s, TRANSITION_FINISH].freeze

  unless AnalysisJobsItem.aasm.events.to_set(&:name).superset?(ALLOWED_TRANSITIONS.to_set(&:to_sym))
    raise 'AnalysisJobsItem::AVAILABLE_ITEM_STATUS is not a subset of AASM events'
  end

  def self.filter_settings
    fields = [
      :id, :analysis_job_id, :audio_recording_id, :script_id,
      :created_at, :queued_at, :work_started_at, :finished_at,
      :queue_id, :error, :attempts,
      :status, :result, :transition, :import_success, :audio_event_import_file_ids
    ]

    {
      valid_fields: fields,
      render_fields: fields,
      text_fields: [:queue_id, :error],
      custom_fields2: {
        # only show field if it's an admin user
        queue_id: {
          query_attributes: [:queue_id],
          transform: ->(item) { Current.user&.admin? ? item.queue_id : nil },
          arel: nil,
          type: :string
        },
        # only show field if it's an admin user - could be sensitive information
        error: {
          query_attributes: [:error],
          transform: ->(item) { Current.user&.admin? ? item.error : nil },
          arel: nil,
          type: :string
        },
        audio_event_import_file_ids: {
          query_attributes: [],
          transform: nil,
          arel: audio_event_import_file_ids_arel,
          type: :array
        }
      },
      controller: :analysis_jobs_items,
      action: :filter,
      defaults: {
        order_by: :audio_recording_id,
        direction: :asc
      },
      valid_associations: [
        {
          join: AnalysisJob,
          on: AnalysisJobsItem.arel_table[:analysis_job_id].eq(AnalysisJob.arel_table[:id]),
          available: true,
          associations: []
        },
        {
          join: Script,
          on: AnalysisJobsItem.arel_table[:script_id].eq(Script.arel_table[:id]),
          available: true
        },
        {
          join: AudioEventImportFile,
          on: AnalysisJobsItem.arel_table[:id].eq(AudioEventImportFile.arel_table[:analysis_jobs_item_id]),
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
          join: AudioRecording,
          on: AnalysisJobsItem.arel_table[:audio_recording_id].eq(AudioRecording.arel_table[:id]),
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
                  available: true,
                  associations: [
                    {
                      join: Project,
                      on: Region.arel_table[:project_id].eq(Project.arel_table[:id]),
                      available: true
                    }
                  ]
                },
                {
                  join: Arel::Table.new(:projects_sites),
                  on: Site.arel_table[:id].eq(Arel::Table.new(:projects_sites)[:site_id]),
                  available: false,
                  associations: [
                    {
                      join: Project,
                      on: Arel::Table.new(:projects_sites)[:project_id].eq(Project.arel_table[:id]),
                      available: true
                    }
                  ]

                }
              ]
            }
          ]
        }
      ]
    }
  end

  def self.schema
    {
      type: 'object',
      additionalProperties: false,
      properties: {
        id: Api::Schema.id,
        analysis_job_id: Api::Schema.id,
        audio_recording_id: Api::Schema.id,
        script_id: Api::Schema.id,
        created_at: Api::Schema.date(read_only: true),
        queued_at: Api::Schema.date(nullable: true, read_only: true),
        work_started_at: Api::Schema.date(nullable: true, read_only: true),
        finished_at: Api::Schema.date(nullable: true, read_only: true),
        queue_id: { type: ['null', 'string'], readOnly: true },
        error: { type: ['null', 'string'], readOnly: true },
        attempts: { type: 'integer', readOnly: true },
        status: { type: 'string', enum: AVAILABLE_ITEM_STATUS, readOnly: true },
        transition: { type: 'string', enum: ALLOWED_TRANSITIONS, readOnly: true },
        result: { type: ['null', 'string'], enum: ALLOWED_RESULTS + [nil], readOnly: true },
        used_walltime_seconds: { type: 'integer', readOnly: true },
        used_memory_bytes: { type: 'integer', readOnly: true },
        audio_event_import_file_ids: Api::Schema.ids(nullable: true, read_only: true),
        import_success: { type: ['null', 'boolean'], readOnly: true }
      },
      required: [
        :id, :analysis_job_id, :audio_recording_id, :script_id,
        :created_at, :queued_at, :work_started_at, :finished_at,
        :queue_id, :error, :attempts,
        :status, :audio_event_import_file_ids, :import_success
      ]
    }.freeze
  end

  #
  # scopes
  #

  # we can't use the aasm .new scope because constructors are named .new!
  scope :status_new, -> { where(status: STATUS_NEW) }

  scope :transition_nil, -> { where(transition: nil) }

  scope :result_nil, -> { where(result: nil) }

  def self.for_analysis_job(analysis_job_id)
    where(analysis_job_id:)
  end

  def self.completed_for_analysis_job(analysis_job_id)
    where(analysis_job_id:, status: COMPLETED_ITEM_STATUS_SYMBOLS)
  end

  def self.failed_for_analysis_job(analysis_job_id)
    where(analysis_job_id:, result: FAILED_RESULTS)
  end

  def self.queued_for_analysis_job(analysis_job_id)
    queued.where(analysis_job_id:)
  end

  def self.failed_arel
    arel_table[:result].in(FAILED_RESULTS)
  end

  def self.not_completed_arel
    arel_table[:status].not_in(COMPLETED_ITEM_STATUS_SYMBOLS)
  end

  def self.to_queue_arel
    arel_table[:transition].eq(TRANSITION_QUEUE)
  end

  def self.to_cancel_arel
    arel_table[:transition].eq(TRANSITION_CANCEL)
  end

  def self.to_retry_arel
    arel_table[:transition].eq(TRANSITION_RETRY)
  end

  def self.to_finish_arel
    arel_table[:transition].eq(TRANSITION_FINISH)
  end

  def self.audio_event_import_file_ids_arel
    aeif = AudioEventImportFile.arel_table
    aji = arel_table

    aeif
      .project(aeif[:id])
      .where(aeif[:analysis_jobs_item_id].eq(aji[:id]))
      .order(aeif[:id].asc)
      .ast => sub_query

    Arel.grouping(sub_query).to_array
  end

  # Returns a query that will select a random sample of analysis job items
  # across multiple jobs that are ready to be enqueued
  # (includes :queue or :retry transitions).
  # It should sample with parity from each job, though the order of the items
  # returned for each job is random.
  # @param limit [Integer] the maximum number of items to return
  # @return [ActiveRecord::Relation]
  def self.sample_for_queueable_across_jobs(limit)
    table = AnalysisJobsItem.arel_table
    random = Arel::Nodes::NamedFunction.new('random', [])
    random_name = 'random_group'
    groupings_cte = Arel::Table.new('groupings')

    # row_number() OVER (PARTITION BY analysis_jobs_items.analysis_job_id order by random()) as random_group
    Arel::Nodes::NamedFunction
      .new('row_number', [])
      .over(
        Arel::Nodes::Window
        .new
        .partition(table[:analysis_job_id])
        .order(random)
      )
      .as(random_name) => window_expression

    table
      .project(table[:id], window_expression)
      .where(to_queue_arel.or(to_retry_arel))
      .order(random_name)
      .take(limit) => groupings_query

    AnalysisJobsItem
      .with(groupings_cte.name => groupings_query)
      .joins(
        table
        .join(groupings_cte)
        .on(table[:id].eq(groupings_cte[:id]))
        .join_sources
      )
      .order(groupings_cte[random_name])
  end

  # Returns analysis job items that are working or queued and that
  # have been working or queued for longer than the specified time.
  # Ordered oldest to newest.
  # Will not fetch items that are marked to transition: these should be
  # processed by other jobs.
  # @param limit [Integer] the maximum number of items to return
  # @param stale_after [Time] the time after which an item is considered stale
  # @return [::ActiveRecord::Relation]
  def self.stale_across_jobs(limit, stale_after:)
    raise ArgumentError, 'stale_after must be a Time' unless stale_after.is_a?(Time)

    table = AnalysisJobsItem.arel_table
    order = table[:created_at].asc

    AnalysisJobsItem
      .where(
        table[:status].in(WORKING_STATUS_SYMBOLS)
        .and(
          table[:work_started_at].lteq(stale_after).or(
            table[:queued_at].lteq(stale_after)
          )
        ).and(
          table[:transition].eq(nil)
        )
      )
      .order(order)
      .take(limit)
  end

  # Returns a relation that will select up to `limit count of analysis job items
  # that need to be cancelled.
  # @param analysis_job [AnalysisJob] the analysis job to select items for
  # @param limit [Integer] the maximum number of items to return
  # @return [ActiveRecord::Relation]
  def self.fetch_cancellable(analysis_job, limit: 1000)
    raise ArgumentError, 'analysis_job must be an AnalysisJob' unless analysis_job.is_a?(AnalysisJob)

    analysis_job
      .analysis_jobs_items
      .where(AnalysisJobsItem.to_cancel_arel)
      .take(limit)
  end

  # Cancels all items for an analysis job.
  # Should be identical to invoking `cancel!` on each item but is more efficient
  # because it batches operations to the remote cluster and database.
  # ! Warning: this method is slow because it must contact the remote queue.
  # ! Must be kept in sync with cancel!
  # ! And yet is still different from cancel! because it will cancel every item
  # ! in the remote queue, despite it's status.
  # @param analysis_job [AnalysisJob] the analysis job to cancel items for
  # @return [::Dry::Monads::Result<Integer>] the number of items cancelled
  def self.cancel_items!(analysis_job)
    raise ArgumentError, 'analysis_job must be an AnalysisJob' unless analysis_job.is_a?(AnalysisJob)

    BawWorkers::Config.batch_analysis.cancel_all_jobs!(analysis_job)
      # only update the database if the remote queue was successfully updated
      .fmap { |_|
        # now update the database
        batch_mark_items_as_cancelled_for_job(analysis_job)
      }
      .alt_map { |error|
        Rails.logger.error("Failed to batch cancel all items for analysis job #{analysis_job.id}", error: error)
        error
      }
  end

  #
  # public methods
  #

  # Checks the job status according to the remote queue.
  # ! Warning: this method is slow because it must contact the remote queue.
  # It will transition this item to the appropriate state if failure is detected.
  # No save is done.
  # The purpose of this is to poll the remote queue to check if the job has
  # completed but for some reason the webhooks in the job failed to update
  # the status already.
  def apply_remote_job_status(batch_status = nil)
    if !batch_status.nil? && !batch_status.is_a?(::BawWorkers::BatchAnalysis::Models::JobStatus)
      raise ArgumentError,
        'batch_status must be a BatchAnalysis::Models::JobStatus'
    end

    # this can happen if the job was never queued, or if it was cancelled
    return if queue_id.blank? || result_cancelled?

    batch_status = BawWorkers::Config.batch_analysis.job_status(self) if batch_status.nil?
    batch_result = batch_status.result&.to_s

    # Read this as:
    # If the job doesn't have a result and we've previously marked this as
    # cancelled then we should keep the cancelled result.
    # We don't have to worry about this
    self.result = batch_result unless batch_result.nil?

    # other attributes
    self.used_walltime_seconds = batch_status.used_walltime_seconds || used_walltime_seconds
    self.used_memory_bytes = batch_status.used_memory_bytes || used_memory_bytes
    append_error(batch_status.error)
  end

  def clear_transition_queue
    clear_transition(TRANSITION_QUEUE)
  end

  def clear_transition_retry
    clear_transition(TRANSITION_RETRY)
  end

  def clear_transition_cancel
    clear_transition(TRANSITION_CANCEL)
  end

  def clear_transition_finish
    clear_transition(TRANSITION_FINISH)
  end

  # The path on the file system where the results of this analysis job item
  # will be stored.
  # Results are partitioned by analysis job id and audio recording uuid, and
  # by script id.
  # @return [Pathname]
  def results_absolute_path
    BawWorkers::Config
      .analysis_cache_helper
      .possible_paths_dir({
        job_id: analysis_job_id,
        uuid: audio_recording.uuid,
        script_id:,
        sub_folders: []
      })
      .first => path

    Pathname(path)
  end

  # Like `results_absolute_path` but without the script id partition.
  # Older analyses did not partition by script id.
  # @note This helper should be avoided in new code.
  # @return [Pathname]
  def results_shared_path
    BawWorkers::Config
      .analysis_cache_helper
      .possible_paths_dir({
        job_id: analysis_job_id,
        uuid: audio_recording.uuid,
        sub_folders: []
      })
      .first => path

    Pathname(path)
  end

  # The path to the job script that was run to produce results
  # ! inferred by convention. May not be accurate
  # @return [Pathname]
  def results_job_path
    # Inferred from the convention in PBS::Connection.submit_job
    # TODO: strongly infer this somehow
    results_absolute_path / ".#{id}"
  end

  # The path to the log file emitted by the job
  # # ! inferred by convention. May not be accurate
  # @return [Pathname]
  def results_job_log_path
    # Inferred from the convention in PBS::Connection.submit_job
    # TODO: strongly infer this somehow
    results_absolute_path / ".#{id}.log"
  end

  def completed?
    COMPLETED_ITEM_STATUS_SYMBOLS.include?(aasm.current_state)
  end

  def append_error(message)
    return if message.blank?

    self.error = error.nil? ? message : "#{error}\n#{message}"
  end

  private

  #
  # other methods
  #

  # clear a transition request.
  # We anticipate some race conditions here so we allow the caller to specify
  # if the transition must match the current transition.
  # @param transition [String,nil] the transition to clear. If `nil` will clear
  #   any transition. If not `nil` will only clear the transition if it matches
  #   the current transition.
  # @return [void]
  def clear_transition(transition)
    return if !transition.nil? && self.transition != transition

    self.transition = nil
  end

  def new_when_created
    errors.add(:status, 'must be new when first created') unless status == :new.to_s
  end

  def transition_set_when_created
    errors.add(:transition, 'must be set to :queue when first created') unless transition_queue?
  end

  def queue_id_set_when_needed
    return if new? || finished?
    return if queue_id.present?

    errors.add(
      :queue_id,
      "A queue_id must be provided when status is not new (current status is #{aasm.current_state})"
    )
  end
end
