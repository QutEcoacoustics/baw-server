# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_jobs
#
#  id                           :integer          not null, primary key
#  annotation_name              :string
#  custom_settings              :text             not null
#  deleted_at                   :datetime
#  description                  :text
#  name                         :string           not null
#  overall_count                :integer          not null
#  overall_data_length_bytes    :bigint           default(0), not null
#  overall_duration_seconds     :decimal(14, 4)   not null
#  overall_progress             :json             not null
#  overall_progress_modified_at :datetime         not null
#  overall_status               :string           not null
#  overall_status_modified_at   :datetime         not null
#  started_at                   :datetime
#  created_at                   :datetime
#  updated_at                   :datetime
#  creator_id                   :integer          not null
#  deleter_id                   :integer
#  saved_search_id              :integer          not null
#  script_id                    :integer          not null
#  updater_id                   :integer
#
# Indexes
#
#  analysis_jobs_name_uidx                 (name,creator_id) UNIQUE
#  index_analysis_jobs_on_creator_id       (creator_id)
#  index_analysis_jobs_on_deleter_id       (deleter_id)
#  index_analysis_jobs_on_saved_search_id  (saved_search_id)
#  index_analysis_jobs_on_script_id        (script_id)
#  index_analysis_jobs_on_updater_id       (updater_id)
#
# Foreign Keys
#
#  analysis_jobs_creator_id_fk       (creator_id => users.id)
#  analysis_jobs_deleter_id_fk       (deleter_id => users.id)
#  analysis_jobs_saved_search_id_fk  (saved_search_id => saved_searches.id)
#  analysis_jobs_script_id_fk        (script_id => scripts.id)
#  analysis_jobs_updater_id_fk       (updater_id => users.id)
#
class AnalysisJob < ApplicationRecord
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # allow a state machine to work with this class
  include AASM
  include AasmHelpers

  OVERALL_PROGRESS_REFRESH_SECONDS = 30.0

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_analysis_jobs
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_analysis_jobs, optional: true
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_analysis_jobs, optional: true

  belongs_to :script, inverse_of: :analysis_jobs
  belongs_to :saved_search, inverse_of: :analysis_jobs
  has_many :projects, through: :saved_search
  has_many :analysis_jobs_items, inverse_of: :analysis_job

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # association validations
  validates_associated :script, :saved_search, :creator

  # attribute validations
  validates :name, presence: true, length: { minimum: 2, maximum: 255 }, uniqueness: { case_sensitive: false }
  validates :custom_settings, :overall_progress, presence: true
  # overall_count is the number of audio_recordings/resque jobs. These should be equal.
  validates :overall_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :overall_duration_seconds, presence: true,
                                       numericality: { only_integer: false, greater_than_or_equal_to: 0 }
  validates :overall_status_modified_at, :overall_progress_modified_at,
            presence: true, timeliness: { on_or_before: -> { Time.zone.now }, type: :datetime }
  validates :started_at, allow_blank: true, allow_nil: true, timeliness: { on_or_before: lambda {
                                                                                           Time.zone.now
                                                                                         }, type: :datetime }
  validates :overall_data_length_bytes, presence: true,
                                        numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  renders_markdown_for :description

  def self.filter_settings
    fields = [
      :id, :name, :description, :annotation_name,
      :custom_settings,
      :creator_id, :updater_id, :deleter_id,
      :created_at, :updated_at, :deleted_at,
      :script_id, :saved_search_id,
      :started_at,
      :overall_status, :overall_status_modified_at,
      :overall_progress, :overall_progress_modified_at,
      :overall_count, :overall_duration_seconds, :overall_data_length_bytes
    ]

    {
      valid_fields: fields,
      render_fields: fields,
      text_fields: [:name, :description, :annotation_name],
      custom_fields: lambda { |item, _user|
        [item, item.render_markdown_for_api_for(:description)]
      },
      new_spec_fields: lambda { |_user|
                         {
                           annotation_name: nil,
                           custom_settings: nil
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

  def self.schema
    {
      type: 'object',
      additionalProperties: false,
      properties: {
        id: { '$ref' => '#/components/schemas/id', readOnly: true },
        name: { type: 'string' },
        annotation_name: { type: ['string', 'null'] },
        **Api::Schema.rendered_markdown(:description),
        custom_settings: { type: 'string' },
        script_id: { '$ref' => '#/components/schemas/id' },
        saved_search_id: { '$ref' => '#/components/schemas/id' },
        started_at: { type: ['null', 'date'], readOnly: true },
        overall_status: { type: 'string', enum: [
          :before_save,
          :new,
          :preparing,
          :processing,
          :completed,
          :suspended
        ], readOnly: true },
        overall_status_modified_at: { type: ['null', 'date'], readOnly: true },
        overall_progress: { type: 'object', readOnly: true },
        overall_progress_modified_at: { type: ['null', 'date'], readOnly: true },
        overall_count: { type: 'integer', readOnly: true },
        overall_duration_seconds: { type: 'number', readOnly: true },
        overall_data_length_bytes: { type: 'integer', readOnly: true },
        **Api::Schema.all_user_stamps
      },
      required: [
        :id,
        :name,
        :description,
        :description_html,
        :description_html_tagline,
        :custom_settings,
        :script_id,
        :saved_search_id,
        :started_at,
        :overall_status,
        :overall_status_modified_at,
        :overall_progress,
        :overall_progress_modified_at,
        :overall_count,
        :overall_duration_seconds,
        :overall_data_length_bytes
      ]
    }.freeze
  end

  #
  # public methods
  #

  def self.batch_size
    1000
  end

  # Intended to be called when we know a change in status has happened -
  # i.e. when an analysis_jobs_item status has changed.
  # Disabled caching idea because it looks like a premature optimization.
  def check_progress
    #if (Time.zone.now - analysis_job.overall_progress_modified_at) > OVERALL_PROGRESS_REFRESH_SECONDS

    # https://github.com/ActsAsParanoid/acts_as_paranoid/issues/45
    was_deleted = deleted?
    if was_deleted
      old_paranoid_value = paranoid_value
      self.paranoid_value = nil
    end

    # skip validations and callbacks, and do not set updated_at, save value to database
    update_columns(update_job_progress)

    # finally, after each update, check if we can finally finish the job!
    complete! if may_complete?

    self.paranoid_value = old_paranoid_value if was_deleted
  end

  # analysis_job lifecycle:
  # 1. When a new analysis job is created, the state will be `before_save`.
  #    The required attributes will be initialised by `initialize_workflow` and state will be transitioned to `new`.
  #    The new analysis job should be saved at this point (and is saved if created via create action on controller).
  #    Note: no AnalysisJobsItems have been made and no resque jobs have been enqueued.
  # 2. Then the job must be prepared. Currently synchronous but designed to be asynchronous.
  #    Do this by calling `prepare` which will transition from `new` to `preparing`.
  #    Note: AnalysisJobsItems are enqueued progressively here. Some actions may be processed and even completed
  #    before the AnalysisJob even finishes preparing!
  # 3. Transition to `processing`
  #    Note: the processing transition should be automatic
  #    Once all resque jobs have been enqueued, the analysis job will transition to 'processing' status.
  # 4. Resque jobs will update the analysis job (via analysis jobs items) as resque jobs change states.
  #    `check_progress` is used to update progress and also is the callback that checks for job completion.
  # 5. When all items have finished processing, the job transitions to `completed`. Users are notified with an email
  #    and the job is marked as completed.
  #
  # Additional states:
  # - Jobs can transition between processing and suspended. When suspended all analysis jobs items are marked as
  #   `cancelling`. When resumed, all `cancelling` items are marked as `queued` again and all `cancelled` items are
  #   re-added back to the queue.
  #   Note: We can't add or remove items from the message queue, which is why we need the cancelling/cancelled
  #   distinction.
  # - Jobs can be retried. In this case, the failed items (only) are re-queued and the job is set to `processing`
  #
  # State transition map
  #
  # :before_save → :new → :preparing → :processing → :completed
  #                           ↑           ↓   ↑          |
  #                           |        :suspended        |
  #                           ----------------------------
  #
  aasm column: :overall_status, no_direct_assignment: true, whiny_persistence: true do
    # We don't need to explicitly set display_name - they get humanized by default
    state :before_save, { initial: true, display_name: 'Before save' }
    state :new, enter: [:initialise_job_tracking, :update_job_progress]
    state :preparing, enter: :send_preparing_email, after_enter: [:prepare_job, :process!]
    state :processing, enter: [:update_job_progress]
    state :suspended, enter: [:suspend_job, :update_job_progress]

    # completed just means all processing has finished, whether it succeeds or not.
    state :completed, enter: [:update_job_progress], after_enter: :send_completed_email

    event :initialize_workflow, unless: :has_status_timestamp? do
      transitions from: :before_save, to: :new
    end

    # we send email here because initialize_workflow does not guarantee that an id is set.
    event :prepare, guard: :has_id? do
      transitions from: :new, to: :preparing
    end

    # you shouldn't need to call process manually
    event :process, guard: :are_all_enqueued? do
      transitions from: :preparing, to: :processing, unless: :all_job_items_completed?
      transitions from: :preparing, to: :completed, guard: :all_job_items_completed?
    end

    event :suspend do
      transitions from: :processing, to: :suspended
    end

    # Guard against race conditions. Do not allow to resume if there are still analysis_jobs_items that are :queued.
    event :resume do
      transitions from: :suspended, to: :processing, guard: :are_all_cancelled?, after: :resume_job
    end

    # https://github.com/aasm/aasm/issues/324
    # event :api_update do
    #   transitions from: :processing, to: :suspended
    #   transitions from: :suspended, to: :processing, guard: :are_all_cancelled?
    # end

    event :complete do
      transitions from: :processing, to: :completed, guard: :all_job_items_completed?
    end

    # retry just the failures
    event :retry do
      transitions from: :completed, to: :processing,
                  guard: :are_any_job_items_failed?, after: [:retry_job, :send_retry_email]
    end

    after_all_transitions :update_status_timestamp
  end

  # job status values
  AVAILABLE_JOB_STATUS_SYMBOLS = aasm.states.map(&:name)
  AVAILABLE_JOB_STATUS = AVAILABLE_JOB_STATUS_SYMBOLS.map(&:to_s)

  AVAILABLE_JOB_STATUS_DISPLAY = aasm.states.map { |x| [x.name, x.display_name] }.to_h

  # hook active record callbacks into state machine
  before_validation(on: :create) do
    # if valid? is called twice, then overall_status already == :new and this will fail. So add extra may_*? check.
    initialize_workflow if may_initialize_workflow?
  end

  private

  #
  # guards for the state machine
  #

  def has_status_timestamp?
    !overall_status_modified_at.nil?
  end

  def has_id?
    !id.nil?
  end

  def are_all_enqueued?
    overall_count == AnalysisJobsItem.for_analysis_job(id).count
  end

  def are_all_cancelled?
    AnalysisJobsItem.queued_for_analysis_job(id).count.zero?
  end

  def all_job_items_completed?
    AnalysisJobsItem.for_analysis_job(id).count == AnalysisJobsItem.completed_for_analysis_job(id).count
  end

  def are_any_job_items_failed?
    AnalysisJobsItem.failed_for_analysis_job(id).count.positive?
  end

  #
  # callbacks for the state machine
  #

  def initialise_job_tracking
    self.overall_count = 0
    self.overall_duration_seconds = 0
    self.overall_data_length_bytes = 0
  end

  def send_preparing_email
    AnalysisJobMailer.new_job_message(self, nil).deliver_now
  end

  # Create payloads from audio recordings extracted from saved search.
  # This method persists changes.
  def prepare_job
    user = Access::Validate.user(creator)

    Rails.logger.info 'AnalysisJob::prepare_job: Begin.'

    # TODO: This may need to be an async operation itself depending on how fast it runs

    # counters
    options = {
      count: 0,
      duration_seconds_sum: 0,
      data_length_bytes_sum: 0,
      queued_count: 0,
      failed_count: 0,
      results: [],
      analysis_job: self
    }

    self.started_at = Time.zone.now
    save!

    # query associated saved_search to get audio_recordings
    query = saved_search.audio_recordings_extract(user)

    options = query
              .find_in_batches(batch_size: AnalysisJob.batch_size)
              .reduce(options, &method(:prepare_analysis_job_item))

    # don't update progress - resque jobs may already be processing or completed
    # the resque jobs can do the updating

    self.overall_count = options[:count]
    self.overall_duration_seconds = options[:duration_seconds_sum]
    self.overall_data_length_bytes = options[:data_length_bytes_sum]
    save!

    Rails.logger.info "AnalysisJob::prepare_job: Complete. Queued: #{options[:queued_count]}"
  end

  # Suspends an analysis job by cancelling all queued items
  def suspend_job
    # get items
    query = AnalysisJobsItem.queued_for_analysis_job(id)

    # batch update
    query.find_in_batches(batch_size: AnalysisJob.batch_size) do |items|
      items.each(&:cancel!)
    end
  end

  # Resumes an analysis job by converting cancelling or cancelled items to queued items
  def resume_job
    # get items
    query = AnalysisJobsItem.cancelled_for_analysis_job(id)

    # batch update
    query.find_in_batches(batch_size: AnalysisJob.batch_size) do |items|
      items.each(&:retry!)
    end
  end

  def send_completed_email
    AnalysisJobMailer.completed_job_message(self, nil).deliver_now
  end

  # Retry an analysis job by re-enqueuing all failed items
  def retry_job
    # get items
    query = AnalysisJobsItem.failed_for_analysis_job(id)

    # batch update
    query.find_in_batches(batch_size: AnalysisJob.batch_size) do |items|
      items.each(&:retry!)
    end
  end

  def send_retry_email
    AnalysisJobMailer.retry_job_message(self, nil).deliver_now
  end

  # Update status timestamp whenever a transition occurs. Does not persist changes - happens before aasm save.
  def update_status_timestamp
    self.overall_status_modified_at = Time.zone.now
  end

  # Update progress and modified timestamp if changes are made. Does NOT persist changes.
  # This callback happens after the AnalysisJob transitions to a new state or when `check_progress` is called.
  # We want all transactions to finish before we update the progresses - since they run a query themselves.
  # @return [void]
  def update_job_progress
    defaults = AnalysisJobsItem::AVAILABLE_ITEM_STATUS.product([0]).to_h
    statuses = AnalysisJobsItem.where(analysis_job_id: id).group(:status).count
    statuses[:total] = statuses.map(&:last).reduce(:+) || 0

    statuses = defaults.merge(statuses)

    self.overall_progress = statuses
    self.overall_progress_modified_at = Time.zone.now

    { overall_progress: overall_progress, overall_progress_modified_at: overall_progress_modified_at }
  end

  #
  # other methods
  #

  # Process a batch of audio_recordings
  def prepare_analysis_job_item(options, audio_recordings)
    audio_recordings.each do |audio_recording|
      # update counters
      options[:count] += 1
      options[:duration_seconds_sum] += audio_recording.duration_seconds
      options[:data_length_bytes_sum] += audio_recording.data_length_bytes

      # create new analysis jobs item
      item = AnalysisJobsItem.new
      item.analysis_job = self
      item.audio_recording = audio_recording

      item.save!

      # now try to transition to queued state (and save if transition successful)
      success = item.queue!
      raise 'Could not queue AnalysisJobItem' unless success

      options[:queued_count] += 1 if item.enqueue_results[:result]
      options[:failed_count] += 1 if item.enqueue_results[:error]

      options[:results].push(item.enqueue_results)
    end

    options
  end
end
