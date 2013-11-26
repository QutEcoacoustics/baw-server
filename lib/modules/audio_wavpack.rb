module AudioWavpack
  include OS, Logging

  # path to the wvunpack executable for different platforms
  @wvunpack_path = if OS.windows? then "./vendor/bin/wavpack/wvunpack.exe" else "wvunpack" end

  public

  # get information about a wav file.
  def self.info_wavpack(source)
    result = {
        :info => { :wavpack => {} },
        :error => { :wavpack => {} }
    }

    # commands to get info from audio file
    wvunpack_command = "#@wvunpack_path -s \"#{source}\""

    # run the commands and wait for the result
    wvunpack_stdout_str, wvunpack_stderr_str, wvunpack_status = Open3.capture3(wvunpack_command)

    #Rails.logger.debug "Wavpack info return status #{wvunpack_status.exitstatus}."

    if wvunpack_status.exitstatus == 0
      # wvunpack std out contains info (separate on first colon(:))
      wvunpack_stdout_str.strip.split(/\r?\n|\r/).each do |line|
        line.strip!
        current_key = line[0,line.index(':')].strip
        current_value = line[line.index(':')+1,line.length].strip
        result[:info][:wavpack][current_key] = current_value
      end

      # wvunpack_stderr_str contains human-formatted info and errors
    else
      result[:error][:wavpack][:stderror] = wvunpack_stderr_str.strip!.split(/\r?\n|\r/).last
    end

    result
  end

  # wvunpack converts .wv files to .wav, optionally segmenting them
  # target should be calculated based on modify_parameters by cache module
  # modify_parameters can contain start_offset (fractions of seconds from start) and/or end_offset (fractions of seconds from start)
  def self.modify_wavpack(source, target, modify_parameters = {})
    raise ArgumentError, "Source is not a wavpack file: #{File.basename(source)}" unless source.match(/\.wv$/)
    raise ArgumentError, "Target is not a wav file: : #{File.basename(target)}" unless target.match(/\.wav$/)
    raise ArgumentError "Source and Target are the same file: #{File.basename(target)}" unless source != target

    if File.exists? target
      return result
    end

    raise ArgumentError, "Source does not exist: #{File.basename(source)}" unless File.exists? source

    # formatted time: hh:mm:ss.ss
    arguments = '-t -q'
    if modify_parameters.include? :start_offset
      start_offset_formatted = Time.at(modify_parameters[:start_offset].to_f).utc.strftime('%H:%M:%S.%2N')
      arguments += " --skip=#{start_offset_formatted}"
    end

    if modify_parameters.include? :end_offset
      end_offset_formatted = Time.at(modify_parameters[:end_offset].to_f).utc.strftime('%H:%M:%S.%2N')
      arguments += " --until=#{end_offset_formatted}"
    end

    wvunpack_command = "#@wvunpack_path #{arguments} \"#{source}\" \"#{target}\"" # commands to get info from audio file

    if OS.windows?
      wvunpack_command = wvunpack_command.gsub(%r{/}) { "\\" }
    end

    wvunpack_stdout_str, wvunpack_stderr_str, wvunpack_status = Open3.capture3(wvunpack_command) # run the commands and wait for the result

    Logging::logger.debug "mp3splt info return status #{wvunpack_status.exitstatus}. Command: #{wvunpack_command}"

    if wvunpack_status.exitstatus != 0 || !File.exists?(target)
      Logging::logger.error "Wvunpack command #{wvunpack_command} exited with an error: #{wvunpack_stderr_str}"
    end

    {
        info: {
            wavpack: {
                command: wvunpack_command,
                source: source,
                target: target,
                parameters: modify_parameters
            }
        }
    }
  end
end
