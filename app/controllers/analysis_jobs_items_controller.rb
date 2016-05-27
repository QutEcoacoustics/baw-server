class AnalysisJobsItemsController < ApplicationController
  include Api::ControllerHelper

  #
  # This controller merges the old `analysis_controller` functionality in with `analysis_jobs_items`. There were two
  # choices here:
  #
  #  - keep the results separate from the job items
  #    e.g. /analysis_jobs/:analysis_job_id/audio_recordings    <- disk data
  #    and  /analysis_jobs/:analysis_job_id/analysis_jobs_items <- database
  #  - or, merge the resources
  #    e.g. /analysis_jobs/:analysis_job_id/audio_recordings
  #
  # We chose the later because:
  #
  # - The data, although stored in different mediums (disk and database) actually represent the same resource -
  #   audio recordings are processed by the job system; thus it is natural that they have results.
  # - Showing a list of audio recordings in the results is a problem that needed solving - if merged that problem gets
  #   solved automatically
  # - Less routes means less client complexity
  #
  # System jobs are run automatically by the system. They don't have analysis_jobs_item records in the database. Rather
  # we proxy requests to audio_recordings table.

  # Warning: this controller does not expose any AnalysisJobsItems by the `id` primary key!

  # GET|HEAD /analysis_jobs/:analysis_job_id/audio_recordings/
  def index
    do_authorize_class
    do_get_opts

    do_get_analysis_job
    query = get_query

    @analysis_jobs_items, opts = Settings.api_response.response_advanced(
        api_filter_params,
        query,
        AnalysisJobsItem,
        AnalysisJobsItem.filter_settings
    )

    respond_index(opts)
  end

  # GET|HEAD /analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id/
  def show
    # TODO: double check permissions
    # - IF analysis_job not deleted

    request_params = do_get_opts

    do_load_resource
    do_authorize_instance
    audio_recording = AudioRecording.find(@audio_recording_id.to_i)

    show_results(request, request_params, {
        analysis_job_id: @analysis_job_id,
        audio_recording_id: @audio_recording_id,
        audio_recording: audio_recording,
        analysis_jobs_item: get_resource
    })
  end

  # Creation/deletion via API not needed at present time.
  # May be needed if we designate saved search execution to a worker.
  # GET /analysis_jobs/:analysis_job_id/audio_recordings/new
  # POST /analysis_jobs/:analysis_job_id/audio_recordings
  # DELETE /analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id

  # PUT|PATCH /analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id
  def update
    do_get_opts

    if @is_system_job
      fail CustomErrors::MethodNotAllowedError.new(
          'Cannot update a system job\'s analysis jobs items',
          [:post, :put, :patch, :delete])
    end

    do_load_resource
    do_authorize_instance

    if @analysis_jobs_item.update_attributes(analysis_jobs_item_update_params)
      respond_show
    else
      respond_change_fail
    end
  end

  # GET|POST  /analysis_jobs/:analysis_job_id/audio_recordings/
  def filter
    do_authorize_class
    do_get_opts

    do_get_analysis_job
    query = get_query

    @analysis_jobs_items, opts = Settings.api_response.response_advanced(
        api_filter_params,
        query,
        AnalysisJobsItem,
        AnalysisJobsItem.filter_settings
    )

    respond_index(opts)
  end

  private

  SYSTEM_JOB_ID = AnalysisJobsController::SYSTEM_JOB_ID

  def analysis_jobs_item_update_params
    # Only status can be updated via API
    # Other properties are updated by the model/initial processing system
    params.require(:analysis_jobs_item).permit(:status)
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

    request_params
  end

  def do_get_analysis_job
    @analysis_job = AnalysisJob.find(@analysis_job_id) unless @is_system_job
  end

  def get_query
    if @is_system_job
      Access::Query.analysis_jobs_items(nil, current_user, true)
    else
      Access::Query.analysis_jobs_items(@analysis_job, current_user, false)
    end
  end

  def get_audio_recording
    if @audio_recording_id.blank? || @audio_recording_id < 1
      fail CustomErrors::UnprocessableEntityError,
           "Invalid audio recording id #{request_params[:audio_recording_id].to_s}."
    end

    @audio_recording = AudioRecording.where(id: request_params[:audio_recording_id]).first
  end


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


  ####################################


  # Pure
  def get_results_path(request_params, analysis_job_id, audio_recording)

    # get sub folders
    request_params[:results_path] = '' unless request_params.include?(:results_path)
    results_path = request_params[:results_path]
    results_paths = Pathname(results_path).each_filename.to_a
    sub_folders = results_paths[0..-2]
    file_name = results_paths[-1]

    {
        job_id: analysis_job_id,
        uuid: audio_recording.uuid,
        sub_folders: sub_folders,
        file_name: file_name.blank? ? '' : file_name
    }
  end

  # pure
  def show_results(request, request_params, options)
    # assume:
    # - analysis_job_id is defined in options
    # - audio_recording_id is defined in options
    # - ~~analysis_job is defined in options~~ - TODO: refactor, this is currently not needed
    # - audio_recording is defined in options
    # - analysis_jobs_item is defined in options (even if it is a fake system version)
    # - the request has been authorized

    # assertion: audio_recordings not in this job should means should not have entered this method - should have been caught by authorization

    # extract parameters for analysis response
    audio_recording = options[:audio_recording]
    analysis_job_id = options[:analysis_job_id]

    results_path_hash = get_results_path(request_params, analysis_job_id, audio_recording)
    is_root_path = results_path_hash[:sub_folders].size == 0
    paths = BawWorkers::Config.analysis_cache_helper.existing_paths(results_path_hash)

    # shared error info
    msg = "Could not find results directory for analysis job '#{analysis_job_id}' for recording '#{audio_recording.id}'" \
      "at '#{request_params[:results_path]}'."

    # should the response include content?
    is_head_request = request.head?

    # can the audio recording be accessed (is it's status ready)?
    is_audio_ready = audio_recording.ready?

    # do initial checking
    if !is_audio_ready && is_head_request
      # changed from 422 Unprocessable entity
      head :not_found
    elsif !is_audio_ready && !is_head_request
      fail CustomErrors::ItemNotFoundError, "Audio recording id #{audio_recording.id} is not ready"
    elsif is_audio_ready && paths.size < 1 && !is_root_path
      # none of the paths are files or directories that exist, so raise error
      # the exception here is the root results folder - it always should 'exist' for the API even if it doesn't on disk
      fail CustomErrors::ItemNotFoundError, msg
    elsif is_audio_ready && (paths.size > 0 || is_root_path)

      if is_root_path
        paths = BawWorkers::Config.analysis_cache_helper.possible_paths_dir(results_path_hash)
        dirs = paths
        files = []
      else
        # files or directories exist
        dirs = paths.select { |p| File.directory?(p) }.map { |d| d.end_with?(File::SEPARATOR + '.') ? d[0..-2] : d }
        files = paths.select { |p| File.file?(p) }
      end

      options[:existing] = {
          dirs: dirs,
          files: files
      }
      options[:is_head_request] = is_head_request
      options[:is_root_path] = is_root_path

      # if paths contains both ... uh, I have no idea. Just fail.
      # also fail if no paths are files or dirs ... I don't know if that's possible or not.
      fail CustomErrors::ItemNotFoundError, msg if (dirs.size > 0 && files.size > 0) || (dirs.size < 1 && files.size < 1)

      # if all files, assume all the same files and return the first one
      return_file(options) if dirs.size < 1 && files.size > 0

      # if all dirs, assume all the same and return file list for first existing dir
      return_dir(options) if dirs.size > 0 && files.size < 1
    else
      fail CustomErrors::BadRequestError, 'There was a problem with the request.'
    end

  end


  def return_file(request_info)
    existing_paths = request_info[:existing][:files]
    is_head_request = request_info[:is_head_request]

    # it is possible to match more than one file (e.g. multiple storage dirs)
    # just return the first existing file
    file_path = existing_paths[0]
    ext = File.extname(file_path).trim('.', '')
    mime_type = Mime::Type.lookup_by_extension(ext)
    mime_type_s = mime_type.to_s
    file_size = File.size(file_path)

    if is_head_request
      head :ok, content_length: file_size, content_type: mime_type_s
    else
      send_file(file_path, url_based_filename: true, type: mime_type_s, content_length: file_size)
    end
  end

  def dir_list(path)
    children = []

    max_items = 50
    items_count = 0

    Dir.foreach(path) do |item|
      # skip dot paths ('current path', 'parent path') and hidden files/folders (that start with a dot)
      next if item == '.' || item == '..' || item.start_with?('.')

      full_path = File.join(path, item)

      children.push(dir_info(full_path)) if File.directory?(full_path)
      children.push(file_info(full_path)) if File.file?(full_path) && !File.directory?(full_path)

      items_count = items_count + 1
      break if items_count >= max_items
    end

    children
  end

  def dir_info(path)
    normalised_path = normalise_path(path)
    normalised_name = normalised_name(normalised_path)

    has_children = false
    Dir.foreach(path) do |item|
      # skip dot paths ('current path', 'parent path') and hidden files/folders (that start with a dot)
      next if item == '.' || item == '..' || item.start_with?('.')

      has_children = true
      break
    end

    {
        path: normalised_path,
        name: normalised_name,
        type: 'directory',
        has_children: has_children
    }
  end

  def dir_info_children(path, is_root_path)
    normalised_path = normalise_path(path)
    normalised_name = normalised_name(normalised_path)

    children = []
    children = dir_list(path) unless is_root_path

    {
        path: normalised_path,
        name: normalised_name,
        type: 'directory',
        children: children
    }
  end

  def file_info(path)
    normalised_path = normalise_path(path)
    normalised_name = normalised_name(normalised_path)

    {
        name: normalised_name,
        type: 'file',
        size_bytes: File.size(path),
        mime: Mime::Type.lookup_by_extension(File.extname(path)[1..-1]).to_s
    }
  end

  def normalised_name(path)
    path == '/' ? '/' : File.basename(path)
  end

  def normalise_path(path)
    analysis_base_paths = BawWorkers::Config.analysis_cache_helper.existing_dirs
    matching_base_path = analysis_base_paths.select { |abp| path.start_with?(abp) }
    if matching_base_path.size == 1
      path_without_base = path.gsub(/#{matching_base_path[0].gsub('/', '\/')}\/[^\/]+\/[^\/]+\/[^\/]+\/?/, '')
      path_without_base.blank? ? '/' : "/#{path_without_base}"
    else
      fail CustomErrors::UnprocessableEntityError, 'Incorrect analysis base path.'
    end
  end

  def return_dir(request_info)
    existing_paths = request_info[:existing][:dirs]
    is_root_path = request_info[:is_root_path]
    is_head_request = request_info[:is_head_request]

    analysis_jobs_item = request_info[:analysis_jobs_item]

    # it is possible to match more than one dir (e.g. multiple storage dirs)
    # just return a file listing for the first existing dir
    dir_path = existing_paths[0]

    dir_listing = dir_info_children(dir_path, is_root_path)

    # merge dir listing with analysis job item
    dir_listing = analysis_jobs_item.attributes.dup.merge(dir_listing)

    wrapped = Settings.api_response.build(:ok, dir_listing)

    json_result = wrapped.to_json
    json_result_size = json_result.size.to_s

    add_header_length(json_result_size)

    if is_head_request
      head :ok, {content_length: json_result_size, content_type: Mime::Type.lookup('application/json')}
    else
      render json: json_result, content_length: json_result_size
    end
  end

end
