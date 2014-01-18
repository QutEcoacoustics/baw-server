require File.dirname(__FILE__) + '/logger'
require File.dirname(__FILE__) + '/OS'

module MediaTools
  class AudioSox

    ERROR_NO_HANDLER = 'FAIL formats: no handler for file extension'
    ERROR_CANNOT_OPEN = 'FAIL formats: can\'t open input file'

    def initialize(sox_executable, temp_dir)
      @sox_executable = sox_executable
      @temp_dir = temp_dir
    end

    def info_command_stat(source)
      # sox std err contains stat output
      "#{@sox_executable} -V2 \"#{source}\" -n stat"
    end

    def info_command_info(source)
      # sox std out contains info
      "#{@sox_executable} --info -V2 \"#{source}\""
    end

    def parse_info_output(output)
      # contains key value output (separate on first colon(:))
      result = {}
      output.strip.split(/\r?\n|\r/).each { |line|
        if line.include?(':')
          colon_index = line.index(':')
          new_value = line[colon_index+1, line.length].strip
          new_key = line[0, colon_index].strip
          result[new_key] = new_value
        end
      }

      result
    end

    def check_for_errors(stdout, stderr)
      raise Exceptions::FileCorruptError if !stderr.blank? && stderr.include?(ERROR_CANNOT_OPEN)
      raise Exceptions::AudioToolError if !stderr.blank? && stderr.include?(ERROR_NO_HANDLER)
    end

    def modify_command(source, target, start_offset = nil, end_offset = nil, channel = nil, sample_rate = nil)
      raise ArgumentError, "Source is not a wav file: #{source}" unless source.match(/\.wav$/)
      raise ArgumentError, "Target is not a wav file: : #{target}" unless target.match(/\.wav$/)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exists? source
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exists? target
      raise ArgumentError "Source and Target are the same file: #{target}" unless source != target


      cmd_offsets = arg_offsets(start_offset, end_offset)
      sample_rate = arg_sample_rate(sample_rate)
      cmd_channel = arg_channel(channel)

      "#{@sox_executable} -q -V4 \"#{source}\" \"#{target}\" #{cmd_offsets} #{sample_rate} #{cmd_channel}"
    end

    def arg_channel(channel)
      cmd_arg = ''
      unless channel.blank?
        channel_number = channel.to_i
        if channel_number < 1
          # mix down to mono
=begin
            Where a range of channels is specified, the channel numbers to the left and right of the hyphen are
            optional and default to 1 and to the number of input channels respectively. Thus
            sox input.wav output.wav remix −
            performs a mix-down of all input channels to mono.
=end
          cmd_arg = ' remix - '
        else
          # select the channel (0 indicates silent channel)
          cmd_arg = " remix #{channel_number} "
        end
      end
      cmd_arg
    end

    def arg_sample_rate(sample_rate)
      cmd_arg = ''
      unless sample_rate.blank?
        # resample quality: medium (m), high (h), veryhigh (v)
        # -s steep filter (band-width = 99%)
        # -a allow aliasing/imaging above the pass-band
        cmd_arg = " rate -v -s -a #{sample_rate}"
      end
      cmd_arg
    end

    def arg_offsets(start_offset, end_offset)
      cmd_arg = ''

      unless start_offset.blank?
        start_offset_formatted = Time.at(start_offset.to_f).utc.strftime('%H:%M:%S.%2N')
        cmd_arg += "trim =#{start_offset_formatted}"
      end

      unless end_offset.blank?
        end_offset_formatted = Time.at(end_offset.to_f).utc.strftime('%H:%M:%S.%2N')
        if start_offset.blank?
          # if start offset was not included, include audio from the start of the file.
          cmd_arg += "trim 0 #{end_offset_formatted}"
        else
          cmd_arg += " =#{end_offset_formatted}"
        end
      end

      cmd_arg
    end

  end
end