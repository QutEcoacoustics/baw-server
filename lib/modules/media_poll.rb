class MediaPoll

  HEADER_KEY_RESPONSE_FROM = 'X-Media-Response-From'
  HEADER_KEY_RESPONSE_START = 'X-Media-Response-Start'

  HEADER_VALUE_RESPONSE_CACHE = 'Cache'
  HEADER_VALUE_RESPONSE_REMOTE = 'Generated Remotely'
  HEADER_VALUE_RESPONSE_LOCAL = 'Generated Locally'

  HEADER_KEY_ELAPSED_TOTAL = 'X-Media-Elapsed-Seconds-Total'
  HEADER_KEY_ELAPSED_PROCESSING = 'X-Media-Elapsed-Seconds-Processing'
  HEADER_KEY_ELAPSED_WAITING = 'X-Media-Elapsed-Seconds-Waiting'

  HEADERS_EXPOSED = [
      'Content-Length',
      HEADER_KEY_RESPONSE_FROM,
      HEADER_KEY_RESPONSE_START,
      HEADER_KEY_ELAPSED_TOTAL,
      HEADER_KEY_ELAPSED_PROCESSING,
      HEADER_KEY_ELAPSED_WAITING
  ].freeze

  class << self

    # this will block the request and wait until at least one of the files is available
    # waits up to wait_max seconds
    # @param [Array<String>] expected_files
    # @param [Number] wait_max
    # @param [Number] poll_delay
    # @return [Array<String>] existing files
    def poll_media(expected_files, wait_max, poll_delay = 0.5)
      #timeout_sec_dir_list = 2.0
      #run_ext_program = BawAudioTools::RunExternalProgram.new(timeout_sec_dir_list, Rails.logger)

      too_long_msg ="Media file was not found within #{wait_max} seconds."

      poll_locations = prepare_locations(expected_files)

      existing_files = []

      poll(too_long_msg, wait_max, poll_delay) do

        existing_files = refresh_files(poll_locations)

        # return true if polling is complete, false to continue polling.
        !existing_files.empty?
      end

      existing_files
    end

    # this will block the request and wait until the resque job is complete
    # waits up to wait_max seconds
    # @param [Symbol] media_type
    # @param [Hash] media_request_params
    # @param [Number] wait_max
    # @param [Number] poll_delay
    # @return [Resque::Plugins::Status::Hash] job status
    def poll_resque(media_type, media_request_params, wait_max, poll_delay = 0.5)

      too_long_msg = "Resque did not complete media request within #{wait_max} seconds."

      status = nil

      poll(too_long_msg+ ' Status: \'' + (status.nil? ? '(none)' : status) + '\'.', wait_max, poll_delay) do
        status = BawWorkers::Media::Action.get_job_status(media_type, media_request_params)
        #current_status = status.status # e.g. Resque::Plugins::Status::STATUS_QUEUED

        # the accuracy of the polling time is the poll_delay
        # for more accurate times, use difference between time and message (when message is 'Completed at <iso8601 time>')
        #time_started = status.time
        #time_finished = status.message

        # true if polling complete, false to continue polling
        # status.queued? || status.working? # job in progress - continue polling or time out

        # job did not complete successfully
        if status.killed? || status.failed?
          status_info = {
              uuid: status.uuid,
              time: status.time,
              status: status.status
          }
          msg = 'Resque job finished with error.'
          fail CustomErrors::AudioGenerationError.new(msg, status_info)
        end

        status.completed? # job completed successfully
      end

      status
    end

    # prepare list of directories and files to poll
    # @param [Array<String>] files
    # @return [Array<Hash>] valid files to poll
    def prepare_locations(files)
      poll_locations = []
      regex_check = /\A(?:\/?[0-9a-zA-Z_\-\.]+)+\z/
      files.each do |raw_file|
        next if raw_file.nil?
        next unless regex_check === raw_file

        file = Pathname.new(raw_file).cleanpath
        next if file.relative?

        # this checks the filesystem, not just the string
        #next unless file.file?

        poll_locations.push(
            {
                dir: file.dirname.to_s,
                file: file.to_s
            })

      end

      poll_locations
    end

    def refresh_files(poll_locations)
      existing_files = []

      poll_locations.each do |location|
        dir = location[:dir]
        file = location[:file]

        # get a valid directory path, and 'refresh' it by getting a file list with -l (executes stat() in linux).
        # This helps avoid problems with nfs directory list caching.
        # only list the file, as the dirs might have quite a few files
        # could also use the external program runner
        # run_ext_program.execute("ls -la \"#{dir}\"") if File.directory?(dir)
        # can also be done by setting the attribute cache time for the nfs mount
        # e.g. 'actimeo=3'
        # @see NFS man page
        system "ls -la \"#{dir}\""

        # once one file exists, break out of this loop and return true
        if File.exists?(file) && File.file?(file)
          existing_files.push(file)
          break
        end

      end

      existing_files.compact
    end

    def check_files(poll_locations)
      existing_files = []

      poll_locations.each do |location|
        dir = location[:dir]
        file = location[:file]

        # once one file exists, break out of this loop and return true
        if File.exists?(file) && File.file?(file)
          existing_files.push(file)
          break
        end

      end

      existing_files.compact
    end

    private

    # Based on Firepoll gem: for knowing when something is ready
    # @param [String] msg a custom message raised when polling fails
    # @param [Numeric] seconds number of seconds to poll, default is two seconds
    # @param [Numeric] delay number of seconds to sleep, default is tenth of a second
    # @yield a block that determines whether polling should continue
    # @yield return false if polling should continue
    # @yield return true if polling is complete
    # @raise [RuntimeError] when polling fails
    # @return the return value of the passed block
    def poll(msg=nil, seconds=2.0, delay=0.1)
      seconds ||= 2.0 # overall patience
      give_up_at = Time.now + seconds # pick a time to stop being patient
      delay ||= 0.1 # wait a tenth of a second before re-attempting

      while Time.now < give_up_at do
        result = yield
        return result if result
        sleep delay
      end
      msg ||= "polling failed after #{seconds} seconds"
      raise msg
    end

  end
end