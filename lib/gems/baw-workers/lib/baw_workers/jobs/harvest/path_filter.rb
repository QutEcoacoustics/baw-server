# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # Very basic path filtering.
      # Not intended to filter everything, only files and directories that we definitely do not want.
      module PathFilter
        module_function

        # @param name [String]
        # @return [Boolean]
        def skip_dir?(name)
          name.start_with?('.') || name == 'System Volume Information'
        end

        # @param name [String]
        # @return [Boolean]
        def skip_file?(name)
          # including .DS_STORE files in particular
          # .filepart files are incomplete WinSCP uploads
          name.start_with?('.') || name == 'Thumbs.db' || name.ends_with?('.filepart')
        end
      end
    end
  end
end
