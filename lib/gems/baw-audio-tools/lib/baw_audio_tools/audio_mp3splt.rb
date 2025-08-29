# frozen_string_literal: true

module BawAudioTools
  class AudioMp3splt
    def initialize(mp3splt_executable, temp_dir)
      @mp3splt_executable = mp3splt_executable
      @temp_dir = temp_dir
    end

    def modify_command(source, _source_info, target, start_offset = nil, end_offset = nil)
      source = Pathname(source)
      target = Pathname(target)
      raise ArgumentError, "Source is not a mp3 file: #{source}" unless source.extname == '.mp3'
      raise ArgumentError, "Target is not a mp3 file: : #{target}" unless target.extname == '.mp3'
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless source.exist?
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if target.exist?
      raise ArgumentError "Source and Target are the same file: #{target}" if source == target

      # mp3splt needs the file extension removed
      target_dirname = target.dirname
      target_no_ext = target.basename('.*')
      cmd_offsets = arg_offsets(start_offset, end_offset)

      "#{@mp3splt_executable} -q -d '#{target_dirname}' -o '#{target_no_ext}' '#{source}' #{cmd_offsets}"
    end

    def arg_offsets(start_offset, end_offset)
      cmd_arg = ''
      # WARNING: can't get more than an hour, since minutes only goes to 59.
      # formatted time: mm.ss.ss
      start_offset_num = 0.0
      if start_offset.blank?
        start_offset = ' 0.0 '
      else
        start_offset = start_offset.to_f
        start_offset = ' ' + (start_offset / 60.0).floor.to_s + '.' + format('%05.2f', start_offset % 60) + ' '
        start_offset_num = start_offset.to_f
      end

      cmd_arg += " #{start_offset} "

      if end_offset.blank?
        cmd_arg += ' EOF '
      else
        end_offset = end_offset.to_f
        end_offset_formatted = (end_offset / 60.0).floor.to_s + '.' + format('%05.2f', end_offset % 60)
        cmd_arg += " #{end_offset_formatted} "
      end

      cmd_arg
    end
  end
end
