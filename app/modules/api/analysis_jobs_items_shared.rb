module Api
  module AnalysisJobsItemsShared
    SYSTEM_JOB_ID = AnalysisJobsItem::SYSTEM_JOB_ID

    private

    def do_load_resource
      if @is_system_job
        resource = AnalysisJobsItem.system_query.find_by(audio_recording_id: @audio_recording_id)
      else
        resource = AnalysisJobsItem.find_by(
            analysis_job_id: @analysis_job_id,
            audio_recording_id: @audio_recording_id
        )
      end

      set_resource(resource)
    end

    def do_get_opts
      # normalise params and get access to rails request instance
      request_params = CleanParams.perform(params.dup)

      if request_params[:analysis_job_id].to_s.downcase == SYSTEM_JOB_ID
        @analysis_job_id = SYSTEM_JOB_ID
        @is_system_job = true
      else
        @analysis_job_id = request_params[:analysis_job_id].to_i
        @is_system_job = false

        if @analysis_job_id.blank? || @analysis_job_id < 1
          fail CustomErrors::UnprocessableEntityError, "Invalid job id #{request_params[:analysis_job_id].to_s}."
        end
      end

      @audio_recording_id = request_params[:audio_recording_id].blank? ? nil : request_params[:audio_recording_id].to_i

      request_params[:analysis_job_id] = @analysis_job_id
      request_params[:audio_recording_id]= @audio_recording_id

      request_params
    end

    def do_get_analysis_job
      # We use with deleted here because we always need to be able to load AnalysisJobsItem even if the parent
      # AnalysisJob has been deleted.
      @analysis_job = AnalysisJob.with_deleted.find(@analysis_job_id) unless @is_system_job
    end

    def get_query
      if @is_system_job
        Access::ByPermission.analysis_jobs_items(nil, current_user, true)
      else
        Access::ByPermission.analysis_jobs_items(@analysis_job, current_user, false)
      end
    end

  end
end
