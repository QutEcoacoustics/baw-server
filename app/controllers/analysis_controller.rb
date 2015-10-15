require 'find'

=begin
  Analysis endpoint definition:
  - case-sensitive
  - for multiple storage locations, will assume identical and pick a file/dir at random.
  - uses permissions for audio recordings
  - responses to get and head requests differ only in inclusion of body content
=end

class AnalysisController < ApplicationController

  # GET|HEAD /analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id
  # GET|HEAD /analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id/*results_path
  def show
    # start timing request
    overall_start = Time.now

    # normalise params and get access to rails request instance
    request_params = CleanParams.perform(params.dup)

    # should the response include content?
    is_head_request = request.head?

    # get all information required
    request_info = get_opts(request_params)

    # extract parameters for analysis response
    analysis_storage_params = request_info[:opts]
    audio_recording = request_info[:audio_recording_info][:audio_recording]
    analysis_job = request_info[:job_info][:analysis_job]
    analysis_job_id = request_info[:job_info][:analysis_job_id]

    # permissions check
    authorize!(:show, audio_recording)
    authorize!(:show, analysis_job) unless analysis_job.nil?

    # can the audio recording be accessed?
    is_audio_ready = audio_recording.status == 'ready'

    paths = BawWorkers::Config.analysis_cache_helper.existing_paths(analysis_storage_params)

    # shared error info
    msg = "Could not find results for job '#{analysis_job_id}' for recording '#{audio_recording.id}' at '#{request_params[:results_path]}'."

    # do initial checking
    if !is_audio_ready && is_head_request
      # changed from 422 Unprocessable entity
      head :not_found
    elsif !is_audio_ready && !is_head_request
      fail CustomErrors::ItemNotFoundError, "Audio recording id #{audio_recording.id} is not ready"
    elsif is_audio_ready && paths.size < 1
      # none of the paths are files or directories that exist, so raise error
      fail CustomErrors::ItemNotFoundError, msg
    elsif is_audio_ready && paths.size > 0
      # files or directories exist

      dirs = paths.select { |p| File.directory?(p) }.map { |d| d.end_with?("#{File::SEPARATOR}.") ? d[0..-2] : d }
      files = paths.select { |p| File.file?(p) }

      request_info[:existing] = {
          dirs: dirs,
          files: files
      }

      request_info[:is_head_request] = is_head_request

      # if paths contains both ... uh, I have no idea. Just fail.
      # also fail if no paths are files or dirs ... I don't know if that's possible or not.
      fail CustomErrors::ItemNotFoundError, msg if (dirs.size > 0 && files.size > 0) || (dirs.size < 1 && files.size < 1)

      # if all files, assume all the same files and return the first one
      return_file(request_info) if dirs.size < 1 && files.size > 0

      # if all dirs, assume all the same and return file list for first existing dir
      return_dir(request_info) if dirs.size > 0 && files.size < 1
    else
      fail CustomErrors::BadRequestError, 'There was a problem with the request.'
    end

  end

  private

  def get_job_opts(request_params)
    system_job_id = 'system'
    job = nil

    if request_params[:analysis_job_id].to_s.downcase == system_job_id
      job_id = system_job_id
    else
      job_id = request_params[:analysis_job_id].to_i
      job = AnalysisJob.find(job_id)
    end

    {
        analysis_job: job,
        analysis_job_id: job_id
    }
  end

  def get_audio_recording_opts(request_params)
    audio_recording_id = request_params[:audio_recording_id].to_i
    audio_recording = AudioRecording.find(audio_recording_id)

    {
        audio_recording: audio_recording,
        audio_recording_id: audio_recording_id
    }
  end

  def get_opts(request_params)
    job_info = get_job_opts(request_params)
    audio_recording_info = get_audio_recording_opts(request_params)

    # get sub folders
    request_params[:results_path] = '' unless request_params.include?(:results_path)
    results_path = request_params[:results_path]
    results_paths = Pathname(results_path).each_filename.to_a
    sub_folders = results_paths[0..-2]
    file_name = results_paths[-1]

    {
        opts: {
            job_id: job_info[:analysis_job_id],
            uuid: audio_recording_info[:audio_recording].uuid,
            sub_folders: sub_folders,
            file_name: file_name.blank? ? '' : file_name
        },
        partial_path_opts: {
            job_id: job_info[:analysis_job_id],
            uuid: audio_recording_info[:audio_recording].uuid,
            sub_folders: results_paths
        },
        job_info: job_info,
        audio_recording_info: audio_recording_info
    }
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

    Dir.foreach(path) do |item|
      # skip dot paths: 'current path' and 'parent path'
      next if item == '.' or item == '..'

      full_path = File.join(path, item)

      children.push(dir_info(full_path)) if File.directory?(full_path)
      children.push(file_info(full_path)) if File.file?(full_path) && !File.directory?(full_path)
    end

    children
  end

  def dir_info(path)
    normalised_path = normalise_path(path)
    normalised_name = normalised_name(normalised_path)

    {
        path: normalised_path,
        name: normalised_name,
        type: 'directory',
        children: dir_list(path)
    }
  end

  def file_info(path)
    normalised_path = normalise_path(path)
    normalised_name = normalised_name(normalised_path)

    {
        path: normalised_path,
        name: normalised_name,
        size: File.size(path),
        type: 'file',
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
      path_without_base.blank? ? '/' : path_without_base
    else
      fail CustomErrors::UnprocessableEntityError, 'Incorrect analysis base path.'
    end
  end

  def return_dir(request_info)
    existing_paths = request_info[:existing][:dirs]
    is_head_request = request_info[:is_head_request]

    # it is possible to match more than one dir (e.g. multiple storage dirs)
    # just return a file listing for the first existing dir
    dir_path = existing_paths[0]

    dir_listing = dir_info(dir_path)

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