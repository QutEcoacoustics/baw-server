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
  validates :started_at, :overall_status_modified_at, :overall_progress_modified_at,
            presence: true, timeliness: {on_or_before: lambda { Time.zone.now }, type: :datetime}

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

  def self.filter_settings
    {
        valid_fields: [:id, :name, :description, :script_id, :saved_search_id, :created_at, :creator_id, :updated_at, :updater_id],
        render_fields: [:id, :name, :description, :script_id, :saved_search_id, :created_at, :creator_id, :updated_at, :updater_id],
        text_fields: [],
        custom_fields: lambda { |analysis_job, user|

          # do a query for the attributes that may not be in the projection
          fresh_analysis_job = AnalysisJob.find(analysis_job.id)

          analysis_job_hash = {}

          saved_search =
              SavedSearch
                  .where(id: fresh_analysis_job.saved_search_id)
                  .select(*SavedSearch.filter_settings[:render_fields])
                  .first

          analysis_job_hash[:saved_search] = saved_search

          script =
              Script
                  .where(id: fresh_analysis_job.script_id)
                  .select(*Script.filter_settings[:render_fields])
                  .first

          analysis_job_hash[:script] = script

          [analysis_job, analysis_job_hash]
        },
        new_spec_fields: lambda { |user|
          {
              annotation_name: nil,
              custom_settings: nil
          }
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

  # Create payloads from audio recordings extracted from saved search.
  # @param [User] user
  # @return [Array<Hash>] payloads
  def saved_search_items_extract(user)
    user = Access::Core.validate_user(user)

    # TODO add logging and timing
    # TODO This may need to be an async operation itself depending on how fast it runs

    # execute associated saved_search to get audio_recordings
    audio_recordings_query = self.saved_search.audio_recordings_extract(user)

    command_format = self.script.executable_command.to_s
    file_executable = ''
    copy_paths = nil
    config_string = self.custom_settings
    job_id = self.id

    # create one payload per each audio_recording
    payloads = []
    audio_recordings_query.find_each(batch_size: 1000) do |audio_recording|
      payloads.push(
          {
              command_format: command_format,
              file_executable: file_executable,
              copy_paths: copy_paths,
              config_string: config_string,
              job_id: job_id,

              uuid: audio_recording.uuid,
              id: audio_recording.id,
              datetime_with_offset: audio_recording.recorded_date.iso8601(3),
              original_format: audio_recording.original_format_calculated
          })
    end

    payloads
  end

  # Enqueue payloads representing audio recordings from saved search to asnc processing queue.
  # @param [User] user
  # @return [Array<Hash>] payloads
  def enqueue_items(user)

    # TODO add logging and timing
    # TODO This may need to be an async operation itself depending on how fast it runs

    payloads = saved_search_items_extract(user)

    results = []

    payloads.each do |payload|

      result = nil
      error = nil

      begin
        result = BawWorkers::Analysis::Action.action_enqueue(payload)
      rescue => e
        error = e
        Rails.logger(self.to_s) { e }
      end

      results.push({payload: payload, result: result, error: error})
    end

    # update status attributes after creating and enqueuing job items
    #update_status_attributes
    # overall_count
    # overall_duration_seconds
    #started_at

    results
  end

  # Gather current status for this analysis job, and update attributes
  # Will set all required values. Uses 0 if required values not given.
  def update_status_attributes(
      status = nil,
      queued_count = nil, working_count = nil,
      successful_count = nil, failed_count = nil)

    # set required attributes to valid values if they are not set
    self.overall_duration_seconds = 0 if self.overall_duration_seconds.blank?
    self.started_at = Time.zone.now if self.started_at.blank?

    # status
    current_status = self.overall_status.blank? ? 'new' : self.overall_status.to_s
    new_status = status.blank? ? current_status : status.to_s

    self.overall_status = new_status
    self.overall_status_modified_at = Time.zone.now if current_status != new_status || self.overall_status_modified_at.blank?

    # progress
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

    # count
    self.overall_count = calculated_total < 0 ? 0 : calculated_total

    self.save
  end

end
