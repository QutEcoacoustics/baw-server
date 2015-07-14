require 'find'

class AnalysisController < ApplicationController
  skip_authorization_check only: [:show]

  def show
    # normalise params and get access to rails request instance
    request_params = CleanParams.perform(params.dup)

    # should the response include content?
    is_head_request = request.head?

    request_info = get_opts(request_params)
    analysis_storage_params = request_info[:opts]
    audio_recording = request_info[:audio_recording_info][:audio_recording]
    job_id = request_info[:job_info][:analysis_job_id]

    paths = BawWorkers::Config.analysis_cache_helper.existing_paths(analysis_storage_params)

    # shared error info
    msg = "Could not find results for job '#{job_id}' for recording '#{audio_recording.id}' in '#{request_params[:results_path]}'."

    if paths.size < 1
      # none of the paths are files or directories that exist, so raise error
      fail CustomErrors::ItemNotFoundError, msg
    else
      # file or directory exists
      dirs = paths.select { |p| File.directory?(p) }
      files = paths.select { |p| File.file?(p) }

      # if paths contains both ... uh, I have no idea. Just fail.
      # also fail if no paths are files or dirs ... I don't know if that's possible or not.
      fail CustomErrors::ItemNotFoundError, msg if (dirs.size > 0 && files.size > 0) || (dirs.size < 1 && files.size < 1)

      # if all files, assume all the same files and return the first one
      return_file(files, is_head_request) if dirs.size < 1 && files.size > 0

      # if all dirs, assume all the same and return file list for first existing dir
      return_dir(dirs, is_head_request)
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
    file_path = existing_paths[0]
    ext = File.extname(file_path).trim('.', '')
    mime_type = Mime::Type.lookup_by_extension(ext)

    if is_head_request
      head :ok, content_length: File.size(file_path), content_type: mime_type.to_s
    else
      send_file(file_path, url_based_filename: true, type: mime_type.to_s, content_length: File.size(file_path))
    end
  end

  def return_dir(existing_paths, is_head_request)

    # listing = {}
    #
    # Find.find(ENV["HOME"]) do |path|
    #   if FileTest.directory?(path)
    #     if File.basename(path)[0] == ?.
    #       Find.prune       # Don't look any further into this directory.
    #     else
    #       next
    #     end
    #   else
    #     total_size += FileTest.size(path)
    #   end
    # end
  end


end