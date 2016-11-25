class AnalysisJobsResultsController < ApplicationController
  include Api::ControllerHelper
  include Api::AnalysisJobsItemsShared

  # GET|HEAD /analysis_jobs/:analysis_job_id/results/
  # GET|HEAD /analysis_jobs/:analysis_job_id/results[/:audio_recording_id][/:path]
  def index
    do_authorize_class(:index, AnalysisJobsItem)
    do_get_opts

    do_get_analysis_job
    @analysis_jobs_items, opts = Settings.api_response.response_advanced(
        api_filter_params,
        get_query,
        AnalysisJobsItem,
        AnalysisJobsItem.filter_settings(@is_system_job)
    )

    show_items_as_results(request.head?, @analysis_jobs_items, opts)
  end

  # GET|HEAD /analysis_jobs/:analysis_job_id/results[/:audio_recording_id][/:path]
  def show
    request_params = do_get_opts

    do_load_resource
    do_authorize_instance(:show, @analysis_jobs_result)

    if @analysis_jobs_result.nil?
      respond_error(
          :not_found,
          "Could not find Audio Recording with id #{@audio_recording_id}",
          {error_info: {audio_recording_id: params[@audio_recording_id]}})
      return
    end

    request_params[:results_path] = '' unless request_params.include?(:results_path)
    @results_path = request_params[:results_path]

    # custom support paging, no other filter options are required
    # standard response functions assume we have an ActiveModel available
    api_opts = Filter::Parse::parse_paging_only(api_filter_params)
    api_opts[:controller] = AnalysisJobsResultsController.controller_name
    api_opts[:action] = action_name
    api_opts[:additional_params] = request_params

    show_results(request.head?, @analysis_jobs_result, @results_path, api_opts)
  end

  private

  def get_base_url_path
    url_for(
        controller: AnalysisJobsResultsController.controller_name,
        action: action_name,
        only_path: true
    )
  end

  def show_items_as_results(is_head_request, analysis_job_items, opts)
    analysis_job_id = @analysis_job_id
    result_roots = BawWorkers::Config.analysis_cache_helper.possible_job_paths_dir({job_id: analysis_job_id})

    ajis_as_hash = analysis_job_items.map do |item|
      hsh = item.as_json
      hsh['path'] = File.join(result_roots[0], item.audio_recording_id.to_s)
      hsh
    end

    respond_with_fake_directory(
        result_roots[0],
        ajis_as_hash,
        result_roots,
        get_base_url_path,
        {analysis_job_id: analysis_job_id},
        is_head_request,
        opts
    )
  end

  # If the result path is a file, then that file is returned.
  # If the result path is a directory, then a directory listing is returned.
  # The directory listing must work on an existing folder but there is one exception: the root directory for the results
  # of an AnalysisJobItem (e.g. GET /analysis_jobs/1/audio_recordings/123/results) will always 'exist' - a fake (empty)
  # directory listing will be returned if it does not exist yet.
  def show_results(is_head_request, analysis_job_item, results_path, api_opts)
    # assertion: audio_recordings must be in the specified job - authorization should filter out those that aren't

    # extract parameters for analysis response
    audio_recording = analysis_job_item.audio_recording
    analysis_job_id = analysis_job_item.analysis_job_id

    results_paths = Pathname(results_path).each_filename.to_a
    sub_folders = results_paths[0..-2]
    file_name = results_paths[-1]
    is_root_path = sub_folders.size == 0 && file_name.blank?

    results_path_arguments = {
        job_id: analysis_job_id,
        uuid: audio_recording.uuid,
        sub_folders: sub_folders,
        file_name: file_name.blank? ? '' : file_name
    }

    if is_root_path
      paths = BawWorkers::Config.analysis_cache_helper.possible_paths_dir(results_path_arguments)
    else
      paths = BawWorkers::Config.analysis_cache_helper.existing_paths(results_path_arguments)
    end

    # shared error info
    msg = "Could not find results directory for analysis job '#{analysis_job_id}' for recording '#{audio_recording.id}'" +
        " at '#{results_path}'."

    # can the audio recording be accessed (is it's status ready)?
    is_audio_ready = audio_recording.ready?

    # do initial checking
    if !is_audio_ready
      # changed from 422 Unprocessable entity
      #head :not_found if is_head_request # disabled head here because render_error should take care of that
      fail CustomErrors::ItemNotFoundError, "Audio recording id #{audio_recording.id} is not ready"

    elsif is_audio_ready
      # for paths that exist, filter out into files or directories
      # the exception is the root results folder - it always should 'exist' for the API even if it doesn't on disk
      dirs = paths
                 .select { |p| is_root_path || File.directory?(p) }
                 .map { |d| d.end_with?(File::SEPARATOR + '.') ? d[0..-2] : d }
      files = paths.select { |p| File.file?(p) }


      # fail if no paths are files or dirs ... I don't know if that's possible or not.
      fail CustomErrors::ItemNotFoundError, msg if dirs.size < 1 && files.size < 1
      # if paths contains both ... uh, I have no idea. Just fail.
      fail CustomErrors::TooManyItemsFoundError, msg if dirs.size > 0 && files.size > 0

      # if all files, assume all the same files and return the first one
      respond_with_file(files, is_head_request) if dirs.size < 1 && files.size > 0

      # if all dirs, assume all the same and return file list for first existing dir
      base_paths = paths.map { |path| get_base_path(path, analysis_job_id, audio_recording.uuid) }
      respond_with_directory(dirs, base_paths, get_base_url_path, analysis_job_item.as_json, is_head_request, api_opts) if dirs.size > 0 && files.size < 1

    else
      fail CustomErrors::BadRequestError, 'There was a problem with the request.'
    end

  end

  def get_base_path(path, analysis_job_id, uuid)
    analysis_base_paths = BawWorkers::Config.analysis_cache_helper.possible_paths_dir(
        {
            job_id: analysis_job_id,
            uuid: uuid,
            sub_folders: [],
            file_name: ''

        })
    matching_base_path = analysis_base_paths.select { |abp| path.start_with?(abp) }

    fail CustomErrors::UnprocessableEntityError, 'Incorrect analysis base path.' if matching_base_path.size != 1

    matching_base_path[0]
  end


end