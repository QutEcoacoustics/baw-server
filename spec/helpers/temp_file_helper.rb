# frozen_string_literal: true

module TempFileHelpers
  module ExampleGroup
    def temp_file(stem: nil, extension: '.tmp')
      stem = ::SecureRandom.hex(7) if stem.blank?
      extension =
        if extension.blank? then ''
        elsif extension.start_with?('.') then extension
        else ".#{extension}"
        end
      path = temp_dir / "#{stem}#{extension}"
      @temp_files << path

      path
    end

    def self.included(example_group)
      example_group.let(:temp_dir) { Pathname(Settings.paths.temp_dir) }

      example_group.before(:all) do
        @temp_files = []
      end

      example_group.before do
        @temp_files.filter(&:exist?).each(&:delete)
      end

      example_group.after do
        @temp_files.filter(&:exist?).each(&:delete)
      end
    end
  end
end
