# Determines file names for cached and original files.
module CacheTools
  class Cache

    attr_reader :original_audio_paths , :cached_audio_paths, :cached_audio_defaults, :cached_spectrogram_defaults, :cached_spectrogram_paths

    public

    def initialize(original_audio_paths, cached_audio_paths, cached_audio_defaults, cached_spectrogram_paths, cached_spectrogram_defaults)
      @original_audio_paths = original_audio_paths
      @cached_audio_paths = cached_audio_paths
      @cached_audio_defaults = cached_audio_defaults
      @cached_spectrogram_paths = cached_spectrogram_paths
      @cached_spectrogram_defaults = cached_spectrogram_defaults
    end

    ###############################
    # original audio
    ###############################
    
    # get the file name for an original audio file
    def original_audio_file(modify_parameters = {})
      file_name = build_parameters [ :uuid, :date, :time, :original_format ], modify_parameters
      file_name
    end

    # get all possible full paths for a file
    def possible_original_audio_paths(file_name)
      possible_paths(@original_audio_paths, file_name)
    end

    # get the full paths for all existing files that match a file name
    def existing_original_audio_paths(file_name)
      existing_paths(@original_audio_paths, file_name)
    end
    
    ###############################
    # cached audio
    ###############################
    
    # get the file name for a cached audio file
    def cached_audio_file(modify_parameters = {})
      file_name = build_parameters [ :uuid, :start_offset, :end_offset, :channel, :sample_rate, :format ], modify_parameters
      file_name
    end

    # get all possible full paths for a file
    def possible_cached_audio_paths(file_name)
      possible_paths(@cached_audio_paths, file_name)
    end

    # get the full paths for all existing files that match a file name
    def existing_cached_audio_paths(file_name)
      existing_paths(@cached_audio_paths, file_name)
    end

    ###############################
    # cached spectrograms
    ###############################
    
    # get the file name for a cached spectrogram
    def cached_spectrogram_file(modify_parameters = {})
      # don't use format here, as we know that spectrograms will be cached in png
      file_name = build_parameters [ :uuid, :start_offset, :end_offset, :channel, :sample_rate, :window, :colour ], modify_parameters
      file_name += '.png'
      file_name
    end

    # get all the storage paths for cached spectrograms
    def cached_spectrogram_storage_paths()
      @cached_spectrogram_paths
    end


    # get all possible full paths for a file
    def possible_cached_spectrogram_paths(file_name)
      possible_paths(@cached_spectrogram_paths, file_name)
    end

    # get the full paths for all existing files that match a file name
    def existing_cached_spectrogram_paths(file_name)
      existing_paths(@cached_spectrogram_paths, file_name)
    end

    ###############################
    # HELPERS
    ###############################

    private
    
    # get all possible full paths for a file
    def possible_paths(storage_paths, file_name)

      possible_paths = storage_paths.collect { |path| File.join(path, build_subfolder(file_name), file_name) }
      possible_paths
    end
    
    # get the full paths for all existing files that match a file name
    def existing_paths(storage_paths, file_name)
      existing_paths = possible_paths(storage_paths, file_name).find_all {|file| File.exists? file }
      existing_paths
    end



    def build_subfolder(file_name)
      # assume that the file name starts with the uuid, get the first two chars as the sub folder
      file_name[0,2]
    end

    def build_parameters(parameter_names = [], modify_parameters = {})

      file_name = ''

      parameter_names.each do |param|
        if param == :uuid
          file_name += get_parameter(:uuid, modify_parameters, false)
        elsif param == :format
          file_name += '.'+get_parameter(:format, modify_parameters, false).reverse.chomp('.').reverse
        elsif param == :original_format
          file_name += '.'+get_parameter(:original_format, modify_parameters, false).reverse.chomp('.').reverse
        elsif [:start_offset, :end_offset].include? param
          file_name += get_parameter(param, modify_parameters, true, :float)
        elsif [:channel, :sample_rate, :window].include? param
          file_name += get_parameter(param, modify_parameters, true, :int)
        elsif [:time].include? param
          # add '-' in front of time
          file_name += get_parameter(param, modify_parameters, true, :string, '-')
        else
          file_name += get_parameter(param, modify_parameters)
        end
      end

      file_name.downcase
    end

    def get_parameter(parameter, modify_parameters, include_separator = true, format = :string, the_separator = '_')
      # need to cater for the situation where modify_parameters contains strings (we want symbols)
      modify_parameters.keys.each do |key|
        modify_parameters[(key.to_sym rescue key) || key] = modify_parameters.delete(key)
      end

      # need to cater for the situation where parameter is a string (we want a symbol)
      parameter = parameter.to_s.to_sym

      raise ArgumentError, "Parameters must include #{parameter}." unless modify_parameters.include? parameter
      result_name = ''

      if modify_parameters.include? parameter
        result_name = modify_parameters[parameter].to_s

        case format
          when :int
            result_name = result_name.to_i.to_s
          when :float
            result_name = result_name.to_f.to_s
          else
            # noop
        end


        #if parameter == :format
        #result_name = result_name.trim '.', ''
        #end

        if include_separator
          result_name = the_separator+result_name
        end
      end

      result_name
    end
  end
end