require 'open3'
require 'benchmark'

module BawAudioTools
  class RunExternalProgram

    # Create a new BawAudioTools::RunExternalProgram.
    # @param [Logger] logger
    # @param [Integer] timeout_sec
    # @return [void]
    def initialize(timeout_sec, logger)
      @logger = logger
      @timeout_sec = timeout_sec

      @class_name = self.class.name
    end

    # Execute an external program.
    # @param [String] command
    # @param [Boolean] raise_exit_error
    # @return [Hash] result hash
    def execute(command, raise_exit_error = true)

      if OS.windows?
        #if command.include? '&& move'
        # if windows and contains a 'move' command, need to ensure relative path has '\' separators
        command = command.gsub('/', '\\')
        #else
        #command = command.gsub('\\', '/')
        #end
      end

      stdout_str = ''
      stderr_str = ''
      status = nil
      timed_out = nil
      killed = nil
      exceptions = []

      time = Benchmark.realtime do
        begin
          run_with_timeout(command, timeout: @timeout_sec) do |output, error, thread, timed_out_return, killed_return, exceptions_inner|
            #thread_success = thread.value.success?
            stdout_str = output
            stderr_str = error
            status = thread.value
            timed_out = timed_out_return
            killed = killed_return
            exceptions = exceptions_inner
          end
        rescue Exception => e
          @logger.fatal(@class_name) { e }
          raise e
        end
      end

      status_msg = "status=#{status.exitstatus};killed=#{killed};"
      timeout_msg = "time_out_sec=#{@timeout_sec};time_taken_sec=#{time};timed_out=#{timed_out};"
      exceptions_msg = "exceptions=#{exceptions.inspect};"
      output_msg = "\n\tStandard output: #{stdout_str}\n\tStandard Error: #{stderr_str}"
      msg = "External Program: #{status_msg}#{timeout_msg}#{exceptions_msg}command=#{command}#{output_msg}"

      if (!stderr_str.blank? && !status.success?) || timed_out || killed
        @logger.warn(@class_name) { msg }
      else
        @logger.debug(@class_name) { msg }
      end

      fail Exceptions::AudioToolTimedOutError, msg if timed_out || killed
      fail Exceptions::AudioToolError, msg if !stderr_str.blank? && !status.success? && raise_exit_error

      {
          command: command,
          stdout: stdout_str,
          stderr: stderr_str,
          time_taken: time,
          exit_code: status.exitstatus,
          execute_msg: msg
      }
    end

    private

    # https://gist.github.com/mgarrick/3108185
    # Runs a specified shell command in a separate thread.
    # If it exceeds the given timeout in seconds, kills it.
    # Passes stdout, stderr, thread, and a boolean indicating a timeout occurred to the passed in block.
    # Uses Kernel.select to wait up to the tick length (in seconds) between
    # checks on the command's status
    #
    # If you've got a cleaner way of doing this, I'd be interested to see it.
    # If you think you can do it with Ruby's Timeout module, think again.

    # Run a command with a timeout.
    # @param [Array] opts
    def run_with_timeout(*opts)
      options = opts.extract_options!.reverse_merge(timeout: 60, tick: 1, cleanup_sleep: 0.1, buffer_size: 10240)

      timeout = options[:timeout]
      cleanup_sleep = options[:cleanup_sleep]

      output = ''
      error = ''

      # Start task in another thread, which spawns a process
      Open3.popen3(*opts) do |stdin, stdout, stderr, thread|
        # Get the pid of the spawned process
        pid = thread[:pid]
        start = Time.now

        exceptions = []
        while (time_remaining = (Time.now - start) < timeout) && thread.alive?
          exceptions.push read_to_stream(stdout, stderr, output, error, options)
        end

        # read to stream a final time to ensure all stdout and stderr have been captured
        # program may have exited so quickly that some was not caught before the while loop
        # was processed again
        exceptions.push read_to_stream(stdout, stderr, output, error, options)

        # Give Ruby time to clean up the other thread
        sleep cleanup_sleep

        killed = false

        if thread.alive?
          # We need to kill the process, because killing the thread leaves
          # the process alive but detached, annoyingly enough.
          Process.kill('KILL', pid)

          killed = true
        end

        yield output, error, thread, !time_remaining, killed, exceptions.flatten
      end
    end

    def read_to_stream(stdout, stderr, output, error, options)
      tick = options[:tick]
      buffer_size = options[:buffer_size]
      exceptions = []
      is_windows = OS.windows?

      # Wait up to `tick` seconds for output/error data
      readables, writeables, = Kernel.select([stdout, stderr], nil, nil, tick)
      unless readables.blank?
        readables.each do |readable|
          stream = readable == stdout ? output : error
          begin
            if is_windows
              read_windows(stream, readable, buffer_size)
            else
              read_linux(stream, readable, buffer_size)
            end
          rescue IO::WaitReadable, EOFError => e
            # Need to read all of both streams
            # Keep going until thread dies
            exceptions.push(e)
          end
        end

        # readables, writeables, = Kernel.select([stdout, stderr], nil, nil, tick)
        # next if readables.blank?
        # output << readables[0].readpartial(buffer_size)
        # error << readables[1].readpartial(buffer_size)
      end

      exceptions
    end

    def read_windows(stream, readable, buffer_size)
      # can't use read_nonblock with pipes in windows (only sockets)
      # https://bugs.ruby-lang.org/issues/5954
      # throw a proper error, then!!! ('Errno::EBADF: Bad file descriptor' is useless)
      stream << readable.readpartial(buffer_size)
    end

    def read_linux(stream, readable, buffer_size)
      stream << readable.read_nonblock(buffer_size)
    end

  end
end