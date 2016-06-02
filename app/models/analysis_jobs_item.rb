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

  SYSTEM_JOB_ID = 'system'

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

    # don't let enumerize set the default value when selecting nil from the database
    new_status = nil if !new_record? && new_status == :new.to_s && old_status == nil

    super(new_status)

    update_status_timestamps(self.status, old_status)

  end

  def analysis_job_id
    super_id = super()
    return SYSTEM_JOB_ID if !new_record? && id.nil?

    super_id
  end

  def self.filter_settings(is_system = false)

    fields = [
        :id, :analysis_job_id, :audio_recording_id,
        :created_at, :queued_at, :work_started_at, :completed_at,
        :queue_id,
        :status
    ]

    settings = {
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

    if is_system
      settings[:base_association] = AnalysisJobsItem.system_query
      settings[:base_association_key] = :audio_recording_id
    end

    settings
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


  # Scoped query for getting fake analysis_jobs.
  # @return [ActiveRecord::Relation]
  def self.system_query
    analysis_jobs_items = self.arel_table

    # alias audio_recordings so other add on queries don't get confused
    audio_recordings_inner = Arel::Table.new(:audio_recordings).alias('tmp_audio_recordings_generator')

    # get a list of all other columns - this ensures attributes don't raise a MissingAttributeException
    columns = (AnalysisJobsItem.column_names - ['audio_recording_id']).map { |c| '"' + table_name + '"."' + c + '"' }

    # then add an extra select to shift the audio_recording.id into audio_recording_id
    projections = columns.unshift("\"#{audio_recordings_inner.name}\".\"id\" AS \"audio_recording_id\"")

    # right outer ensures audio_recordings generate 'fake'(empty) analysis_jobs_items rows
    # we make sure the join condition always fails - we don't want the outer join to match real rows
    joined = analysis_jobs_items
                 .project(*projections)
                 .join(audio_recordings_inner, Arel::Nodes::RightOuterJoin)
                 .on(audio_recordings_inner[:id].eq(nil))

    # convert to sub-query - hides weird table names
    subquery = joined.as(analysis_jobs_items.table_name)

    # cast back to active record relation
    query = from(subquery)

    # merge with AudioRecording to apply default scope (e.g. where deleted_at IS NULL)
    query_without_deleted = query.joins(:audio_recording)

    query_without_deleted
  end

  private

  def is_new_when_created
    unless status == :new
      errors.add(:status, 'must be new when first created')
    end
  end

  def has_queue_id_when_needed
    if !(status == :new) && queue_id.blank?
      errors.add(:queue_id, 'A queue_id must be provided when status is not new')
    end
  end
end
