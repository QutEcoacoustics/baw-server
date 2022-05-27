# frozen_string_literal: true

module TempFileHelpers
  module Example
    #
    # Generate a temp file that is automatically cleaned up after a test.
    # Does not create the file.
    #
    # @param [String] stem the basename for the temp file's name. If nil a random name will be used.
    # @param [String] extension the extension for the temp file. '.tmp' by default.
    #
    # @return [Pathname] The path to the temp file.
    #
    def temp_file(basename: nil, stem: nil, extension: '.tmp')
      unless basename.nil?
        extension = File.extname(basename)
        stem = File.basename(basename, extension)
      end

      stem = ::SecureRandom.hex(7) if stem.blank?
      extension =
        if extension.blank? then ''
        elsif extension.start_with?('.') then extension
        else
          ".#{extension}"
        end

      path = temp_dir / "#{stem}#{extension}"

      set_temp_files(get_temp_files + [path])

      path
    end

    # Generates a path segment with between 0 and depth segments long.
    def generate_random_sub_directories(depth: 4)
      Random.rand(depth - 1).times.reduce('') { |previous, _| "#{previous}#{::SecureRandom.hex(4)}/" }
    end

    def self.included(example_group)
      example_group.define_metadata_state :temp_files, default: []
      example_group.let(:temp_dir) { Pathname(Settings.paths.temp_dir) }

      example_group.before do
        logger.info('before: deleting temp files', temp_files: get_temp_files)
        get_temp_files.each do |file|
          FileUtils.remove_file(file, force: true)
        end
      end

      example_group.after do
        logger.info('after: deleting temp files', temp_files: get_temp_files)
        get_temp_files.each do |file|
          FileUtils.remove_file(file, force: true)
        end
      end
    end
  end
end
