# frozen_string_literal: false

# mutable strings needed in this file where stdout is read into variable with <<

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
      stdout_str = ''
      stderr_str = ''
      status = nil
      timed_out = nil
      killed = nil
      exceptions = []
      pid = nil

      time = Benchmark.realtime do

        run_with_timeout(command, timeout: @timeout_sec) do |output, error, thread, timed_out_return, killed_return, exceptions_inner, pid_inner|
          #thread_success = thread.value.success?
          stdout_str = output
          stderr_str = error
          status = thread.value
          timed_out = timed_out_return
          killed = killed_return
          exceptions = exceptions_inner
          pid = pid_inner
        end
      rescue Exception => e
        @logger.fatal(@class_name) do e end
        raise e

      end

      status_msg = "status=#{status.exitstatus};killed=#{killed};pid=#{pid};"
      timeout_msg = "time_out_sec=#{@timeout_sec};time_taken_sec=#{time};timed_out=#{timed_out};"
      exceptions_msg = "exceptions=#{exceptions.inspect};"
      output_msg = "\n\tStandard output: #{stdout_str}\n\tStandard Error: #{stderr_str}\n\n"
      msg = "External Program: #{status_msg}#{timeout_msg}#{exceptions_msg}command=#{command}#{output_msg}"

      if (!stderr_str.blank? && !status.success?) || timed_out || killed
        @logger.warn(@class_name) { msg }
      else
        @logger.debug(@class_name) { msg }
      end

      raise Exceptions::AudioToolTimedOutError, msg if timed_out || killed
      raise Exceptions::AudioToolError, msg if !status.success? && raise_exit_error

      {
        command: command,
        stdout: stdout_str,
        stderr: stderr_str,
        time_taken: time,
        exit_code: status.exitstatus,
        success: status.success?,
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
      options = opts.extract_options!.reverse_merge(timeout: 60, tick: 1, cleanup_sleep: 0.1, buffer_size: 10_240)

      timeout = options[:timeout]
      cleanup_sleep = options[:cleanup_sleep]

      output = ''
      error = ''

      # Start task in another thread, which spawns a process
      Open3.popen3(*opts) do |_stdin, stdout, stderr, thread|
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
          # Sending TERM (15) instead of KILL (9) to allow clean up rather than
          # dirty exit
          Process.kill('TERM', pid)

          killed = true
        end

        # Give process time to clean up
        sleep cleanup_sleep

        yield output, error, thread, !time_remaining, killed, exceptions.flatten, pid
      end
    end

    def read_to_stream(stdout, stderr, output, error, options)
      tick = options[:tick]
      buffer_size = options[:buffer_size]
      exceptions = []

      # Wait up to `tick` seconds for output/error data
      readables, writeables, = Kernel.select([stdout, stderr], nil, nil, tick)
      unless readables.blank?
        readables.each do |readable|
          stream = readable == stdout ? output : error
          begin
            read_linux(stream, readable, buffer_size)
          rescue IO::WaitReadable => e
            # Need to read all of both streams
            # Keep going until thread dies
            exceptions.push(e)
          rescue EOFError => e
            # ignore EOFErrors
          end
        end

        # readables, writeables, = Kernel.select([stdout, stderr], nil, nil, tick)
        # next if readables.blank?
        # output << readables[0].readpartial(buffer_size)
        # error << readables[1].readpartial(buffer_size)
      end

      exceptions
    end

    def read_linux(stream, readable, buffer_size)
      stream << readable.read_nonblock(buffer_size)
    end
  end
end
