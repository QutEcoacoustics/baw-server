# frozen_string_literal: true

module BawAudioTools
  class AudioWac2wav
    def initialize(wac2wav_executable, temp_dir)
      @wac2wav_executable = wac2wav_executable
      @temp_dir = temp_dir
    end

    def info(source)
      source = source.to_s
      raise ArgumentError, "Source is not a wac file: #{source}" unless source.match(/\.wac$/)
      raise Exceptions::AudioFileNotFoundError, "Could not find #{source}." unless File.exist?(source)

      # WAac header format:
      # https://github.com/QutBioacoustics/wac2wavcmd/blob/master/wac2wavcmd.c#L214
      # https://github.com/QutBioacoustics/wac2wavcmd/blob/master/wac2wavcmd.c#L40
      header_size = 24 # first 24 bytes are the WAC header
      file_size = File.size(source)
      raise Exceptions::FileTooSmallError, "File was too small to be a WAC file #{source}." if file_size <= header_size

      offset = 0
      header = IO.read(source, header_size, offset, mode: 'r')

      # if this is a WAC header
      is_wac = header[0..3] == 'WAac'
      raise Exceptions::NotAnAudioFileError, "Source file header indicates it is not a WAC file #{source}" unless is_wac

      # source is a wac file, get the information
      header_bytes = header.bytes.to_a

      # 'V' = 32-bit unsigned, VAX (little-endian) byte order
      # 'v' = 16-bit unsigned, VAX (little-endian) byte order
      le32 = 'V'
      le16 = 'v'

      flag_value = header[0x0a..0x0b].unpack1(le16)
      bits_per_sample = 16

      info = {
        version: header_bytes[0x04],
        channels: header_bytes[0x05],
        frame_size: header[0x06..0x07].unpack1(le16),
        block_size: header[0x08..0x09].unpack1(le16),
        flags: {
          wac: flag_value & 0x0f,
          triggered: flag_value & 0x10,
          gps: flag_value & 0x20,
          tag: flag_value & 0x40
        },
        sample_rate: header[0x0c..0x0f].unpack1(le32),
        sample_count: header[0x10..0x13].unpack1(le32),
        seek_size: header[0x14..0x15].unpack1(le16),
        seek_entries: header[0x16..0x17].unpack1(le16),
        data_length_bytes: file_size,
        media_type: 'audio/x-waac',
        bit_rate_bps: bits_per_sample
      }

      info[:duration_seconds] = (info[:sample_count].to_f / info[:sample_rate].to_f).round(3)

      info
    end

    def modify_command(source, target)
      raise ArgumentError, "Source is not a wac file: #{source}" unless source.to_s.match(/\.wac$/)
      raise ArgumentError, "Target is not a wav file: : #{target}" unless target.to_s.match(/\.wav$/)
      raise Exceptions::FileNotFoundError, "Source does not exist: #{source}" unless File.exist? source
      raise Exceptions::FileAlreadyExistsError, "Target exists: #{target}" if File.exist? target
      raise ArgumentError "Source and Target are the same file: #{target}" if source == target

      # wac file is read from stdin, wav file is written to stdout
      "#{@wac2wav_executable} < \"#{source}\" > \"#{target}\""
    end
  end
end
