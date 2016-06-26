class AnalysisJob < ActiveRecord::Base
  extend Enumerize

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_analysis_jobs
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_analysis_jobs
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_analysis_jobs

  belongs_to :script, inverse_of: :analysis_jobs
  belongs_to :saved_search, inverse_of: :analysis_jobs
  has_many :projects, through: :saved_search
  has_many :analysis_jobs_items, inverse_of: :analysis_job

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # store progress as json in a text column
  # this stores jason in the form
  # { queued: 5, working: 10, successful: 4, failed: 3, total: 22}
  serialize :overall_progress, JSON

  # association validations
  validates :script, existence: true
  validates :saved_search, existence: true
  validates :creator, existence: true

  # attribute validations
  validates :name, presence: true, length: {minimum: 2, maximum: 255}, uniqueness: {case_sensitive: false}
  validates :custom_settings, :overall_progress, presence: true
  # overall_count is the number of audio_recordings/resque jobs. These should be equal.
  validates :overall_count, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}
  validates :overall_duration_seconds, presence: true, numericality: {only_integer: false, greater_than_or_equal_to: 0}
  validates :overall_status_modified_at, :overall_progress_modified_at,
            presence: true, timeliness: {on_or_before: lambda { Time.zone.now }, type: :datetime}
  validates :started_at, allow_blank: true, allow_nil: true, timeliness: {on_or_before: lambda { Time.zone.now }, type: :datetime}
  validates :overall_data_length_bytes, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}

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

  enumerize :overall_status, in: AVAILABLE_JOB_STATUS, predicates: true

  #
  # State transition map
  #
  # :new → :preparing → :processing → :completed
  #                           ⇅
  #                       :suspended
  #

  after_initialize :initialise_job_tracking, if: Proc.new { |analysis_job| analysis_job.new_record? }

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
        new_spec_fields: lambda { |user|
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

  # analysis_job lifecycle:
  # 1. when a new analysis job is created, the required attributes will be initialised by `initialise_job_tracking`
  # the new analysis job can be saved at this point (and is saved if created via create action on controller),
  # but it has not been started and no resque jobs have been enqueued
  # 2. Start an analysis job by calling `begin_work`. Calling `begin_work` when :overall_status is not 'new' or analysis job has not been saved is an error
  # If :overall_status is 'new', the analysis job will immediately transition to 'preparing' status, then create and enqueue resque jobs.
  # 3. Once all resque jobs have been enqeued, the analysis job will transition to 'processing' status.
  # 4. resque jobs will update the analysis job as resque jobs change states using `update_job_progress`
  # TODO more...


  # Update status and modified timestamp if changes are made. Does not persist changes.
  # @param [Symbol, String] status
  # @return [void]
  def update_job_status(status)
    current_status = self.overall_status.blank? ? 'new' : self.overall_status.to_s
    new_status = status.blank? ? current_status : status.to_s

    self.overall_status = new_status
    self.overall_status_modified_at = Time.zone.now if current_status != new_status || self.overall_status_modified_at.blank?
  end

  # Update progress and modified timestamp if changes are made. Does not persist changes.
  # @param [Integer] queued_count
  # @param [Integer] working_count
  # @param [Integer] successful_count
  # @param [Integer] failed_count
  # @return [void]
  def update_job_progress(queued_count = nil, working_count = nil, successful_count = nil, failed_count = nil)
    current_progress = self.overall_progress

    current_queued_count = current_progress.blank? ? 0 : current_progress['queued'].to_i
    current_working_count = current_progress.blank? ? 0 : current_progress['working'].to_i
    current_successful_count = current_progress.blank? ? 0 : current_progress['successful'].to_i
    current_failed_count = current_progress.blank? ? 0 : current_progress['failed'].to_i

    new_queued_count = queued_count.blank? ? current_queued_count : queued_count.to_i
    new_working_count = working_count.blank? ? current_working_count : working_count.to_i
    new_successful_count = successful_count.blank? ? current_successful_count : successful_count.to_i
    new_failed_count = failed_count.blank? ? current_failed_count : failed_count.to_i

    calculated_total = new_queued_count + new_working_count + new_successful_count + new_failed_count

    new_progress = {
        queued: new_queued_count,
        working: new_working_count,
        successful: new_successful_count,
        failed: new_failed_count,
        total: calculated_total,
    }

    self.overall_progress = new_progress
    self.overall_progress_modified_at = Time.zone.now if current_progress != new_progress || self.overall_progress_modified_at.blank?
  end

  def create_payload(audio_recording)

    # common payload info
    command_format = self.script.executable_command.to_s
    file_executable = ''
    copy_paths = []
    config_string = self.custom_settings.to_s
    job_id = self.id.to_i

    {
        command_format: command_format,

        # TODO: where do file_executable and copy_paths come from?
        file_executable: file_executable,
        copy_paths: copy_paths,

        config: config_string,
        job_id: job_id,

        uuid: audio_recording.uuid,
        id: audio_recording.id,
        datetime_with_offset: audio_recording.recorded_date.iso8601(3),
        original_format: audio_recording.original_format_calculated
    }
  end

  # Create payloads from audio recordings extracted from saved search.
  # @param [User] user
  # @return [Array<Hash>] payloads
  def begin_work(user)
    user = Access::Validate.user(user)

    # ensure status is 'new' and analysis job has been saved
    if self.overall_status != 'new' || !self.persisted?
      msg_status = self.overall_status == 'new' ? '' : " Status must be 'new', but was '#{self.overall_status}'."
      msg_saved = self.persisted? ? '' : ' Analysis job has not been saved.'
      fail CustomErrors::AnalysisJobStartError.new("Analysis job cannot start.#{msg_status}#{msg_saved}")
    end

    # TODO add logging and timing
    # TODO This may need to be an async operation itself depending on how fast it runs

    # counters
    count = 0
    duration_seconds_sum = 0
    data_length_bytes_sum = 0
    queued_count = 0
    failed_count = 0

    # update status and started timestamp
    update_job_status('preparing')
    self.started_at = Time.zone.now if self.started_at.blank?
    self.save!

    # query associated saved_search to get audio_recordings
    query = self.saved_search.audio_recordings_extract(user)

    # create one payload per each audio_recording
    results = []
    query.find_each(batch_size: 1000) do |audio_recording|
      payload = create_payload(audio_recording)

      # update counters
      count = count + 1
      duration_seconds_sum = duration_seconds_sum + audio_recording.duration_seconds
      data_length_bytes_sum = data_length_bytes_sum + audio_recording.data_length_bytes

      # Enqueue payloads representing audio recordings from saved search to asynchronous processing queue.
      result = nil
      error = nil

      begin
        result = BawWorkers::Analysis::Action.action_enqueue(payload)
        queued_count = queued_count + 1
      rescue => e
        error = e
        Rails.logger.error "An error occurred when enqueuing an analysis job item: #{e}"
        failed_count = failed_count + 1
      end

      results.push({payload: payload, result: result, error: error})
    end

    # update counters, status, progress
    update_job_status('processing')
    # don't update progress - resque jobs may already be processing or completed
    # the resque jobs can do the updating
    self.overall_count = count
    self.overall_duration_seconds = duration_seconds_sum
    self.overall_data_length_bytes = data_length_bytes_sum
    self.save!

    results
  end

  private

  def initialise_job_tracking
    update_job_status('new')
    update_job_progress
    self.overall_count = 0 if self.overall_count.blank?
    self.overall_duration_seconds = 0 if self.overall_duration_seconds.blank?
    self.overall_data_length_bytes = 0 if self.overall_data_length_bytes.blank?
  end
end
