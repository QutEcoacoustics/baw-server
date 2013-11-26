require File.dirname(__FILE__) + '/logger'
require File.dirname(__FILE__) + '/OS'

module AudioSox
include OS, Logging
  @sox_path = if OS.windows? then "./vendor/bin/sox/sox.exe" else "sox" end

  # public methods
  public

  def self.info_sox(source)
    result = {
        :info => { :sox => {} },
        :error => { :sox => {} }
    }

    sox_arguments_info = "--info -V4"
    sox_command = "#{@sox_path} #{sox_arguments_info} \"#{source}\"" # commands to get info from audio file
    sox_stdout_str, sox_stderr_str, sox_status = Open3.capture3(sox_command) # run the commands and wait for the result

    Logging::logger.debug  "sox info return status #{sox_status.exitstatus}. Command: #{sox_command}"

    if sox_status.exitstatus == 0
      # sox std out contains info (separate on first colon(:))
      sox_stdout_str.strip.split(/\r?\n|\r/).each { |line|
        if line.include?(':')
          colon_index = line.index(':')
          new_value = line[colon_index+1,line.length].strip
          new_key = line[0,colon_index].strip
          result[:info][:sox][new_key] = new_value
        end
      }
      # sox_stderr_str is empty
    else
      Logging::logger.error "Sox info error. Return status #{sox_status.exitstatus}. Command: #{sox_command}"
      result[:error][:sox][:stderror] = sox_stderr_str
    end

    result
  end

  def self.modify_sox(source, target, modify_parameters = {})
    raise ArgumentError, "Source is not a mp3 or wav file: #{File.basename(source)}" unless source.match(/\.mp3|\.wav$/)
    raise ArgumentError, "Target is not a mp3 or wav file: : #{File.basename(target)}" unless target.match(/\.mp3|\.wav$/)
    raise ArgumentError, "Source does not exist: #{File.basename(source)}" unless File.exists? source
    raise ArgumentError, "Target exists: #{File.basename(target)}" unless !File.exists? target

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
      # help... not sure how to do this
      # HACK: WARNING this will always mix down to mono
      arguments += ' remix - '
    end

    # −q, −−no−show−progress
    # Run in quiet mode when SoX wouldn’t otherwise do so. This is the opposite of the −S option.

    sox_command = "#@sox_path -q -V4 \"#{source}\" \"#{target}\" #{arguments}" # commands to get info from audio file
    sox_stdout_str, sox_stderr_str, sox_status = Open3.capture3(sox_command) # run the commands and wait for the result

    Logging::logger.debug  "Sox command #{sox_command}"

    if sox_status.exitstatus != 0 || !File.exists?(target)
      Logging::logger.error "Sox exited with an error: #{sox_stderr_str}"
    end

    result
  end

end