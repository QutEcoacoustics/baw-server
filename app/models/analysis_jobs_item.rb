class AnalysisJobsItem < ActiveRecord::Base
  extend Enumerize


  belongs_to :analysis_job, inverse_of: :analysis_jobs_items
  belongs_to :audio_recording, inverse_of: :analysis_jobs_items


  # association validations
  validates :analysis_job, existence: true
  validates :audio_recording, existence: true

  # attribute validations
  validates :status, presence: true, length: {minimum: 2, maximum: 255}
  validates :queue_id, uniqueness: {case_sensitive: true}

  validate :is_new_when_created, on: :create
  validate :has_queue_id_when_needed

  validates :created_at,
            presence: true,
            timeliness: {on_or_before: lambda { Time.zone.now }, type: :datetime},
            unless: :new_record?

  validates :queued_at, :work_started_at, :completed_at,
            allow_blank: true, allow_nil: true,
            timeliness: {on_or_before: lambda { Time.zone.now }, type: :datetime}

  # item status values - timed out is a special failure case where the worker never reports back
  AVAILABLE_ITEM_STATUS_SYMBOLS = [:new, :queued, :working, :successful, :failed, :timed_out, :cancelled]
  AVAILABLE_ITEM_STATUS = AVAILABLE_ITEM_STATUS_SYMBOLS.map { |item| item.to_s }

  AVAILABLE_JOB_STATUS_DISPLAY = [
      {id: :new, name: 'New'},
      {id: :queued, name: 'Queued'},
      {id: :working, name: 'Working'},
      {id: :successful, name: 'Successful'},
      {id: :failed, name: 'Failed'},
      {id: :timed_out, name: 'Timed out'},
      {id: :cancelled, name: 'Cancelled'},
  ]

  enumerize :status, in: AVAILABLE_ITEM_STATUS, predicates: true, default: :new

  #
  # State transition map
  #                             --> :successful
  #                             |
  # :new → :queued → :working ----> :failed
  #   |       |          |      |
  #   |       |          |      --> :timed_out
  #   |       |          |
  #   --------------------------> :cancelled
  #
  # IFF #retry implemented (not currently the case), then also:
  #
  #   :failed ---------> :queued
  #                |
  #   :timed_out ---

  def status=(new_status)
    old_status = self.status

    super(new_status)

    update_status_timestamps(self.status, old_status)

  end


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
                available: true
            },
            {
                join: AudioRecording,
                on: AnalysisJobsItem.arel_table[:audio_recording_id].eq(AudioRecording.arel_table[:id]),
                available: true
            }
        ]
    }
  end

  # Special filter settings
  def self.filter_settings_system

    fields = [
        :audio_recording_id
    ]

    {
        valid_fields: fields,
        render_fields: fields,
        #text_fields: ,
        controller: :analysis_jobs_items,
        action: :filter,
        defaults: {
            order_by: :audio_recording_id,
            direction: :asc
        },
        valid_associations: [
            {
                join: AudioRecording,
                on: AnalysisJobsItem.arel_table[:audio_recording_id].eq(AudioRecording.arel_table[:id]),
                available: true
            }
        ]
    }
  end


  # Update status and modified timestamp if changes are made. Does not persist changes.
  # @param [Symbol] new_status
  # @param [Symbol] old_status
  # @return [void]
  def update_status_timestamps(new_status, old_status)
    return if new_status == old_status

    case
      #when new_status == :new and old_status == :new
      #  created_at = Time.zone.now  # - created_at handled by rails
      when (new_status == :queued and old_status == :new)
        queued_at = Time.zone.now
      when (new_status == :working and old_status == :queued)
        work_started_at = Time.zone.now
      when (new_status == :successful and old_status == :working),
           (new_status == :failed and old_status == :working),
           (new_status == :timed_out and old_status == :working)
        completed_at = Time.zone.now
      when (new_status == :cancelled and old_status == :new),
           (new_status == :cancelled and old_status == :queued),
           (new_status == :cancelled and old_status == :working)
        completed_at = Time.zone.now
      else
        fail "AnalysisJobItem#status: Invalid state transition from #{ old_status } to #{ new_status }"
    end
  end

  def self.system_query
    joins('RIGHT OUTER JOIN audio_recordings on analysis_jobs_items.audio_recording_id = audio_recordings.id')
        .select('"audio_recordings"."id" AS "analysis_jobs_items"."audio_recording_id"')
        .order(created_at: :desc)
  end

  private

  def is_new_when_created
    unless status == :new
      errors.add(:status, 'must be new when first created')
    end
  end

  def has_queue_id_when_needed
    if  !(status == :new) && queue_id.blank?
      errors.add(:queue_id, 'A queue_id must be provided when status is not new')
    end
  end
end
