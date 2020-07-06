# frozen_string_literal: true

module BawAudioTools
  class AudioWavpack
    ERROR_NOT_COMPATIBLE = 'not compatible with this version of WavPack file!'
    ERROR_NOT_VALID = 'not a valid WavPack file!'
    ERROR_CANNOT_OPEN = 'can\'t open file'

    def initialize(wavpack_executable, temp_dir)
      @wavpack_executable = wavpack_executable
      @temp_dir = temp_dir
    end

    def info_command(source)
      "#{@wavpack_executable} -s \"#{source}\""
    end

    def integrity_command(source)
      "#{@wavpack_executable} -v \"#{source}\""
    end

    def parse_info_output(output)
      # wvunpack std out contains info (separate on first colon(:))
      result = {}
      output.strip.split(/\r?\n|\r/).each do |line|
        line.strip!
        current_key = line[0, line.index(':')].strip
        current_value = line[line.index(':') + 1, line.length].strip
        result[current_key] = current_value
      end

      result
    end

    def parse_error_output(output)
      output.strip!.split(/\r?\n|\r/).last
    end

    def check_for_errors(execute_msg)
      #stdout = execute_msg[:stdout]
      stderr = execute_msg[:stderr]

      if !stderr.blank? && stderr.include?(ERROR_CANNOT_OPEN)
        raise Exceptions::FileCorruptError, "Wavpack could not open the file.\n\t#{execute_msg[:execute_msg]}"
      end
      if !stderr.blank? && stderr.include?(ERROR_NOT_VALID)
        raise Exceptions::AudioToolError, "Wavpack was given a non-wavpack file.\n\t#{execute_msg[:execute_msg]}"
      end
      if !stderr.blank? && stderr.include?(ERROR_NOT_COMPATIBLE)
        raise Exceptions::AudioToolError, "Wavpack was given a non-compatible wavpack file.\n\t#{execute_msg[:execute_msg]}"
      end
    end

    def check_integrity_output(execute_msg)
      #stdout = execute_msg[:stdout]
      stderr = execute_msg[:stderr]

      result = {
        errors: [],
        info: {
          operation: '',
          time: 0,
          mode: '',
          ratio: ''
        }
      }

      return result if stderr.blank?

      stderr.each_line do |line|
        info_match = /([^\s]+?) [^ ]+? in ([^ ]+?) secs \((.*?), (.*?)\)/i.match(line)
        if info_match.blank?
          #result.errors.push(line)
        else
          result[:info][:operation] = info_match[1]
          result[:info][:time] = info_match[2]
          result[:info][:mode] = info_match[3]
          result[:info][:ratio] = info_match[4]
        end
      end

      # consider verification failed if info is not populated
      result[:errors].push('Verification failed') if result[:info][:operation].blank?

      result
    end

    def modify_command(source, _source_info, target, start_offset = nil, end_offset = nil)
      raise ArgumentError, "Source is not a wavpack file: #{source}" unless source.match(/\.wv$/)
      raise ArgumentError, "Target is not a wav file: : #{target}" unless target.match(/\.wav$/)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exist? source
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exist? target
      raise ArgumentError "Source and Target are the same file: #{target}" if source == target

      cmd_offsets = arg_offsets(start_offset, end_offset)

      wvunpack_command = "#{@wavpack_executable} #{cmd_offsets} \"#{source}\" -o \"#{target}\""
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
