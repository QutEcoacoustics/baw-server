require 'find'

class AnalysisController < ApplicationController
  skip_authorization_check only: [:show]

  def show
    # start timing request
    overall_start = Time.now

    # normalise params and get access to rails request instance
    request_params = CleanParams.perform(params.dup)

    # should the response include content?
    is_head_request = request.head?

    # permissions are checked in
    # get_opts -> get_audio_recording_opts -> authorise_custom
    request_info = get_opts(request_params)

    # extract parameters for analysis response
    analysis_storage_params = request_info[:opts]
    audio_recording = request_info[:audio_recording_info][:audio_recording]
    job_id = request_info[:job_info][:analysis_job_id]

    # can the audio recording be accessed?
    is_audio_ready = audio_recording.status == 'ready'

    paths = BawWorkers::Config.analysis_cache_helper.existing_paths(analysis_storage_params)

    # shared error info
    msg = "Could not find results for job '#{job_id}' for recording '#{audio_recording.id}' in '#{request_params[:results_path]}'."

    # do initial checking
    if !is_audio_ready && is_head_request
      # changed from 422 Unprocessable entity
      head :not_found
    elsif !is_audio_ready && !is_head_request
      fail CustomErrors::ItemNotFoundError, "Audio recording id #{audio_recording.id} is not ready"
    elsif is_audio_ready && paths.size < 1
      # none of the paths are files or directories that exist, so raise error
      fail CustomErrors::BadRequestError, msg
    elsif is_audio_ready && paths.size > 0
      # files or directories exist
      dirs = paths.select { |p| File.directory?(p) }
      files = paths.select { |p| File.file?(p) }

      # if paths contains both ... uh, I have no idea. Just fail.
      # also fail if no paths are files or dirs ... I don't know if that's possible or not.
      fail CustomErrors::ItemNotFoundError, msg if (dirs.size > 0 && files.size > 0) || (dirs.size < 1 && files.size < 1)

      # if all files, assume all the same files and return the first one
      return_file(files, is_head_request) if dirs.size < 1 && files.size > 0

      # if all dirs, assume all the same and return file list for first existing dir
      return_dir(dirs, is_head_request) if dirs.size > 0 && files.size < 1
    else
      fail CustomErrors::BadRequestError, 'There was a problem with the request.'
    end

  end

  private

  def authorise_custom(request_params, user)

    # Can't do anything if not logged in, not in user or admin role, or not confirmed
    if user.blank? || (!Access::Check.is_standard_user?(user) && !Access::Check.is_admin?(user)) || !user.confirmed?
      fail CanCan::AccessDenied, 'Anonymous users, non-admin and non-users, or unconfirmed users cannot access analysis data.'
    end

    auth_custom_audio_recording(request_params.slice(:audio_recording_id))
  end

  def get_job_opts(request_params)
    system_job_id = 'system'
    job = nil

    if request_params[:analysis_job_id].to_s.downcase == system_job_id
      job_id = system_job_id
    else
      job_id = request_params[:analysis_job_id].to_i

      if job_id.blank? || job_id < 1
        fail CustomErrors::UnprocessableEntityError, "Invalid job id #{request_params[:analysis_job_id].to_s}."
      end

      job = AnalysisJob.where(id: job_id).first
    end

    {
        analysis_job: job,
        analysis_job_id: job_id
    }
  end

  def get_audio_recording_opts(request_params)
    audio_recording_id = request_params[:audio_recording_id].to_i

    if audio_recording_id.blank? || audio_recording_id < 1
      fail CustomErrors::UnprocessableEntityError, "Invalid audio recording id #{request_params[:audio_recording_id].to_s}."
    end

    # check audio_recording authorisation
    audio_recording = authorise_custom(request_params, current_user)

    {
        audio_recording: audio_recording,
        audio_recording_id: audio_recording_id
    }
  end

  def get_opts(request_params)
    job_info = get_job_opts(request_params)
    audio_recording_info = get_audio_recording_opts(request_params)

    # get sub folders
    results_path = request_params[:results_path]
    results_paths = Pathname(results_path).each_filename.to_a

    {
        opts:
            {
                job_id: job_info[:analysis_job_id],
                uuid: audio_recording_info[:audio_recording].uuid,
                sub_folders: results_paths[0..-2],
                file_name: results_paths[-1]
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

  def return_file(existing_paths, is_head_request)
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

  def dir_listing_start(dir_path)
    listing = {}

    current_dir = dir_path
    current_listing = {
        dir: current_dir,
        sub_dirs: [],
        files: []
    }

    Find.find(dir_path) do |path|
      if FileTest.directory?(path)
        is_dot_dir = File.basename(path)[0] == ?.
        is_too_deep = path.scan(%r{/}).size > 4
        if is_dot_dir || is_too_deep
          # Don't look any further into this directory.
          Find.prune
        else
          current_listing[:sub_dirs].push(
              {
                  dir: File.basename(path),
                  sub_dirs: [],
                  files: []
              })
          next
        end
      else
        current_listing[:files].push(
            {
                name: File.basename(path),
                size: FileTest.size(path)
            })
      end
    end

    listing
  end

  def add_file_listing(listing, path)
    path_components = Pathname(path).each_filename.to_a

    {
        name: File.basename(path),
        size: FileTest.size(path)
    }
  end

  def add_dir_listing(listing, path)
    path_components = Pathname(path).each_filename.to_a

    {
        dir: File.basename(dir),
        sub_dirs: [],
        files: []
    }
  end


  def dir_listing(dir)
    {
        dir: File.basename(dir),
        sub_dirs: [],
        files: []
    }
  end

  def return_dir(existing_paths, is_head_request)
    # it is possible to match more than one dir (e.g. multiple storage dirs)
    # just return a file listing for the first existing dir
    dir_path = existing_paths[0]

    dir_listing = dir_listing_start(dir_path)

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