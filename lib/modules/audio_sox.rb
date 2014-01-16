require File.dirname(__FILE__) + '/logger'
require File.dirname(__FILE__) + '/OS'

module MediaTools
  class AudioSox
    include Logging

    def initialize(sox_executable, temp_dir)
      @sox_executable = sox_executable
      @temp_dir = temp_dir
    end

    # public methods
    public

    def info(source)
      result = {
          :info => {:sox => {}},
          :error => {:sox => {}}
      }

      # basic audio file info
      sox_command = "#{@sox_executable} --info -V2 \"#{source}\"" # commands to get info from audio file
      sox_stdout_str, sox_stderr_str, sox_status = Open3.capture3(sox_command) # run the commands and wait for the result

      Logging::logger.debug "sox info return status #{sox_status.exitstatus}. Command: #{sox_command}"

      if sox_status.exitstatus == 0
        # sox std out contains info (separate on first colon(:))
        sox_stdout_str.strip.split(/\r?\n|\r/).each { |line|
          if line.include?(':')
            colon_index = line.index(':')
            new_value = line[colon_index+1, line.length].strip
            new_key = line[0, colon_index].strip
            result[:info][:sox][new_key] = new_value
          end
        }
        # sox_stderr_str is empty
      else
        result[:error][:sox][:stderror] = sox_stderr_str
        Logging::logger.error "Sox info error: #{result[:error][:sox]}"
      end

      # detailed audio info
      sox_command = "#{@sox_executable} -V2 \"#{source}\" -n stat" # commands to get info from audio file
      sox_stdout_str, sox_stderr_str, sox_status = Open3.capture3(sox_command) # run the commands and wait for the result

      Logging::logger.debug "sox stat return status #{sox_status.exitstatus}. Command: #{sox_command}"

      if sox_status.exitstatus == 0
        # sox std err contains stat output (separate on first colon(:))
        sox_stderr_str.strip.split(/\r?\n|\r/).each { |line|
          if line.include?(':')
            colon_index = line.index(':')
            new_value = line[colon_index+1, line.length].strip
            new_key = line[0, colon_index].strip
            result[:info][:sox][new_key] = new_value
          end
        }
      else
        result[:error][:sox][:stderror] += sox_stderr_str
        Logging::logger.error "Sox stat error: #{result[:error][:sox]}"
      end

      result
    end

    def modify(source, target, modify_parameters = {})
      raise ArgumentError, "Source is not a mp3 or wav file: #{source}" unless source.match(/\.mp3|\.wav$/)
      raise ArgumentError, "Target is not a mp3 or wav file: : #{target}" unless target.match(/\.mp3|\.wav$/)
      raise ArgumentError, "Source does not exist: #{source}" unless File.exists? source
      raise ArgumentError, "Target exists: #{target}" if File.exists? target

      result = {}

      # order matters!
      arguments = ''

      # start and end offset
      if modify_parameters.include? :start_offset
        start_offset_formatted = Time.at(modify_parameters[:start_offset].to_f).utc.strftime('%H:%M:%S.%2N')
        arguments += "trim =#{start_offset_formatted}"
      end

      if modify_parameters.include? :end_offset
        end_offset_formatted = Time.at(modify_parameters[:end_offset].to_f).utc.strftime('%H:%M:%S.%2N')
        if modify_parameters.include? :start_offset
          arguments += " =#{end_offset_formatted}"
        else
          # if start offset was not included, include audio from the start of the file.
          arguments += "trim 0 #{end_offset_formatted}"
        end
      end

      # resample quality: medium (m), high (h), veryhigh (v)
      if modify_parameters.include? :sample_rate
        arguments += " rate -v -s -a #{modify_parameters[:sample_rate]}"
      end

=begin
      Where a range of channels is specified, the channel numbers to the left and right of the hyphen are
      optional and default to 1 and to the number of input channels respectively. Thus
      sox input.wav output.wav remix −
      performs a mix-down of all input channels to mono.
=end
      if modify_parameters.include? :channel
        channel_number = modify_parameters[:channel].to_i
        if channel_number < 1
          # mix down to mono
          arguments += ' remix - '
        else
          # select the channel (0 indicates silent channel)
          arguments += " remix #{channel_number} "
        end
      end

      # −q, −−no−show−progress
      # Run in quiet mode when SoX wouldn’t otherwise do so. This is the opposite of the −S option.

      sox_command = "#{@sox_executable} -q -V4 \"#{source}\" \"#{target}\" #{arguments}" # commands to get info from audio file
      sox_stdout_str, sox_stderr_str, sox_status = Open3.capture3(sox_command) # run the commands and wait for the result

      Logging::logger.debug "Sox command #{sox_command}"

      if sox_status.exitstatus != 0 || !File.exists?(target)
        Logging::logger.error "Sox exited with an error: #{sox_stderr_str}"
      end

      result
    end
  end
end