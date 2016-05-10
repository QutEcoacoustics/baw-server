module BawAudioTools
  class AudioWac2wav

    def initialize(wac2wav_executable, temp_dir)
      @wac2wav_executable = wac2wav_executable
      @temp_dir = temp_dir
    end

    def modify_command(source, target)
      # wac file is read from stdin, wav file is written to stdout
      "#{@wac2wav_executable} < \"#{source}\" > \"#{target}\""
    end

  end
end