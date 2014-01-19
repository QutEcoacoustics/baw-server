require File.dirname(__FILE__) + '/logger'

module MediaTools
  class AudioWavpack

    ERROR_NOT_COMPATIBLE = 'not compatible with this version of WavPack file!'
    ERROR_NOT_VALID = 'not a valid WavPack file!'
    ERROR_CANNOT_OPEN = 'can\'t open file'

    def initialize(wavpack_executable, temp_dir)
      @wavpack_executable = wavpack_executable
      @temp_dir = temp_dir
    end

    public

    def info_command(source)
      "#{@wavpack_executable} -s \"#{source}\""
    end

    def parse_info_output(output)
      # wvunpack std out contains info (separate on first colon(:))
      result = {}
      output.strip.split(/\r?\n|\r/).each do |line|
        line.strip!
        current_key = line[0, line.index(':')].strip
        current_value = line[line.index(':')+1, line.length].strip
        result[current_key] = current_value
      end

      result
    end

    def parse_error_output(output)
      output.strip!.split(/\r?\n|\r/).last
    end

    def check_for_errors(stdout, stderr)
      raise Exceptions::FileCorruptError if !stderr.blank? && stderr.include?(ERROR_CANNOT_OPEN)
      raise Exceptions::AudioToolError if !stderr.blank? && stderr.include?(ERROR_NOT_VALID)
      raise Exceptions::AudioToolError if !stderr.blank? && stderr.include?(ERROR_NOT_COMPATIBLE)
    end

    def modify_command(source, source_info, target, start_offset = nil, end_offset = nil)
      raise ArgumentError, "Source is not a wavpack file: #{source}" unless source.match(/\.wv$/)
      raise ArgumentError, "Target is not a wav file: : #{target}" unless target.match(/\.wav$/)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exists? target
      raise ArgumentError "Source and Target are the same file: #{target}" unless source != target

      cmd_offsets = arg_offsets(start_offset, end_offset)

      wvunpack_command = "#{@wavpack_executable} #{cmd_offsets} \"#{source}\" \"#{target}\""
      wvunpack_command = wvunpack_command.gsub(%r{/}) { "\\" } if OS.windows?
      wvunpack_command
    end

    def arg_offsets(start_offset, end_offset)
      # formatted time: hh:mm:ss.ss
      cmd_arg = '-t -q'
      unless start_offset.blank?
        start_offset_formatted = Time.at(start_offset.to_f).utc.strftime('%H:%M:%S.%2N')
        cmd_arg += " --skip=#{start_offset_formatted}"
      end

      unless end_offset.blank?
        end_offset_formatted = Time.at(end_offset.to_f).utc.strftime('%H:%M:%S.%2N')
        cmd_arg += " --until=#{end_offset_formatted}"
      end

      cmd_arg
    end

    def parse_duration(duration_string)
      # 0:01:10.02
      duration_match = /(?<hour>\d+):(?<minute>\d+):(?<second>\d+)\.(?<fraction>\d+)/i.match(duration_string)
      duration = 0
      if !duration_match.nil? && duration_match.size == 5
        duration = (duration_match[:hour].to_f * 60 * 60) + (duration_match[:minute].to_f * 60) + duration_match[:second].to_f + (duration_match[:fraction].to_f / 100)
      end
      duration
    end

  end
end