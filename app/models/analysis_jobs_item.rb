# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_jobs_items
#
#  id                 :integer          not null, primary key
#  cancel_started_at  :datetime
#  completed_at       :datetime
#  queued_at          :datetime
#  status             :string(255)      default("new"), not null
#  work_started_at    :datetime
#  created_at         :datetime         not null
#  analysis_job_id    :integer          not null
#  audio_recording_id :integer          not null
#  queue_id           :string(255)
#
# Indexes
#
#  index_analysis_jobs_items_on_analysis_job_id     (analysis_job_id)
#  index_analysis_jobs_items_on_audio_recording_id  (audio_recording_id)
#  queue_id_uidx                                    (queue_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (analysis_job_id => analysis_jobs.id)
#  fk_rails_...  (audio_recording_id => audio_recordings.id)
#
class AnalysisJobsItem < ApplicationRecord
  # allow a state machine to work with this class
  include AASM
  include AasmHelpers

  # ensure we allow with_deleted here for race condition where analysis job
  # has been soft deleted while job items are still updating
  belongs_to :analysis_job, -> { with_deleted }, inverse_of: :analysis_jobs_items
  belongs_to :audio_recording, inverse_of: :analysis_jobs_items

  #validates_associated :analysis_job
  #validates_associated :audio_recording

  # attribute validations
  validates :status, presence: true, length: { minimum: 2, maximum: 255 }
  validates :queue_id, uniqueness: { case_sensitive: true }

  validate :new_when_created, on: :create
  validate :queue_id_set_when_needed

  validates :created_at,
    presence: true,
    timeliness: { on_or_before: -> { Time.zone.now }, type: :datetime },
    unless: :new_record?

  validates :queued_at, :work_started_at, :completed_at,
    allow_blank: true, allow_nil: true,
    timeliness: { on_or_before: -> { Time.zone.now }, type: :datetime }

  def self.filter_settings
    fields = [
      :id, :analysis_job_id, :audio_recording_id,
      :created_at, :queued_at, :work_started_at, :completed_at,
      :queue_id,
      :status
    ]

    {
      valid_fields: fields,
      render_fields: fields,
      text_fields: [:queue_id],
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
          associations: [
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

  #
  # scopes
  #

  def self.for_analysis_job(analysis_job_id)
    where(analysis_job_id:)
  end

  def self.completed_for_analysis_job(analysis_job_id)
    where(analysis_job_id:, status: COMPLETED_ITEM_STATUS_SYMBOLS)
  end

  def self.failed_for_analysis_job(analysis_job_id)
    where(analysis_job_id:, status: FAILED_ITEM_STATUS_SYMBOLS)
  end

  def self.queued_for_analysis_job(analysis_job_id)
    queued.where(analysis_job_id:)
  end

  def self.cancelled_for_analysis_job(analysis_job_id)
    where(analysis_job_id:, status: [:cancelling, :cancelled])
  end

  #
  # public methods
  #

  attr_reader :enqueue_results

  def status=(new_status)
    old_status = status

    # don't let enumerize set the default value when selecting nil from the database
    new_status = nil if !new_record? && new_status == :new.to_s && old_status.nil?

    super(new_status)
  end

  #
  # State transition map
  #                             --> :successful
  #                             |
  # :new → :queued → :working ----> :failed
  #           |                 |
  #           |                 --> :timed_out
  #           |
  #           ----> :cancelling --> :cancelled
  #
  # Retry an item:
  #
  # :failed ---------> :queued
  #              |
  # :timed_out ---
  #
  # During cancellation:
  #
  #  :cancelling --> :queued (same queue_id)
  #
  # After cancellation:
  #
  #  :cancelled --> :queued (new queue_id)
  #
  # Avoid race conditions for cancellation: an item can always finish!
  #
  # :cancelling ⊕ :cancelled ----> :successful ⊕ :failed ⊕ :timed_out
  #
  aasm column: :status, no_direct_assignment: true, whiny_persistence: true do
    state :new, initial: true
    state :queued, before_enter: :add_to_queue, enter: :set_queued_at
    state :working, enter: :set_work_started_at
    state :successful, enter: :set_completed_at
    state :failed, enter: :set_completed_at
    state :timed_out, enter: :set_completed_at
    state :cancelling, enter: :set_cancel_started_at
    state :cancelled, enter: :set_completed_at

    event :queue, guards: [] do
      transitions from: :new, to: :queued
    end

    event :work, guards: [] do
      transitions from: :queued, to: :working
    end

    event :succeed, guards: [] do
      transitions from: :working, to: :successful
      transitions from: [:cancelling, :cancelled], to: :successful
    end

    event :fail, guards: [] do
      transitions from: :working, to: :failed
      transitions from: [:cancelling, :cancelled], to: :failed
    end

    event :time_out, guards: [] do
      transitions from: :working, to: :timed_out
      transitions from: [:cancelling, :cancelled], to: :timed_out
    end

    # https://github.com/aasm/aasm/issues/324
    # event :complete, guards: [] do
    #   transitions from: :working, to: :successful
    #   transitions from: :working, to: :failed
    #   transitions from: :working, to: :timed_out
    #   transitions from: [:cancelling, :cancelled], to: :successful
    #   transitions from: [:cancelling, :cancelled], to: :failed
    #   transitions from: [:cancelling, :cancelled], to: :timed_out
    # end

    event :cancel, guards: [] do
      transitions from: :queued, to: :cancelling
    end

    event :confirm_cancel, guards: [] do
      transitions from: :cancelling, to: :cancelled
    end

    event :retry, guards: [] do
      transitions from: [:failed, :timed_out], to: :queued
      transitions from: :cancelled, to: :queued
      transitions from: :cancelling, to: :queued
    end
  end

  # item status values - timed out is a special failure case where the worker never reports back
  AVAILABLE_ITEM_STATUS_SYMBOLS = aasm.states.map(&:name)
  AVAILABLE_ITEM_STATUS = AVAILABLE_ITEM_STATUS_SYMBOLS.map(&:to_s)

  AVAILABLE_ITEM_STATUS_DISPLAY = aasm.states.to_h { |x| [x.name, x.display_name] }

  COMPLETED_ITEM_STATUS_SYMBOLS = [:successful, :failed, :timed_out, :cancelled].freeze
  FAILED_ITEM_STATUS_SYMBOLS = [:failed, :timed_out, :cancelled].freeze

  private

  #
  # state machine guards
  #

  #
  # state machine callbacks
  #

  # Enqueue payloads representing audio recordings from saved search to asynchronous processing queue.
  def add_to_queue
    if !queue_id.blank? && cancelling?
      # cancelling items already have a valid job payload on the queue - do not add again
      return
    end

    payload = AnalysisJobsItem.create_action_payload(analysis_job, audio_recording)

    result = nil
    error = nil

    begin
      result = BawWorkers::Jobs::Analysis::Job.action_enqueue(payload)

      # the assumption here is that result is a unique identifier that we can later use to interrogate the message queue
      self.queue_id = result
    rescue StandardError => e
      # NOTE: exception used to be swallowed. We might need better error handling here later on.
      Rails.logger.error "An error occurred when enqueuing an analysis job item: #{e}"
      raise
    end

    @enqueue_results = { result:, error: }
  end

  def set_queued_at
    self.queued_at = Time.zone.now
  end

  def set_work_started_at
    self.work_started_at = Time.zone.now
  end

  def set_cancel_started_at
    self.cancel_started_at = Time.zone.now
  end

  def set_completed_at
    self.completed_at = Time.zone.now
  end

  #
  # other methods
  #

  def self.create_action_payload(analysis_job, audio_recording)
    # common payload info
    command_format = analysis_job.script.executable_command.to_s
    config_string = analysis_job.custom_settings.to_s
    job_id = analysis_job.id.to_i

    # get base options for analysis from the script
    # Options invariant to the AnalysisJob are stuck in here, like:
    # - file_executable
    # - copy_paths
    payload = (analysis_job.script.analysis_action_params || {}).dup.deep_symbolize_keys

    # merge base
    payload.merge({
      command_format:,

      config: config_string,
      job_id:,

      uuid: audio_recording.uuid,
      id: audio_recording.id,
      datetime_with_offset: audio_recording.recorded_date.iso8601(3),
      original_format: audio_recording.original_format_calculated
    })
  end

  def new_when_created
    errors.add(:status, 'must be new when first created') unless status == :new.to_s
  end

  def queue_id_set_when_needed
    return unless status != :new.to_s && queue_id.blank?

    errors.add(:queue_id, 'A queue_id must be provided when status is not new')
  end
end
