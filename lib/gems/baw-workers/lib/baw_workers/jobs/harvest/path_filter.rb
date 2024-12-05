# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # Very basic path filtering.
      # Not intended to filter everything, only files and directories that we definitely do not want.
      module PathFilter
        module_function

        # Checks whether or not we should skip a directory by name.
        # Expects a single path fragment, the directory name only.
        # @param name [String]
        # @return [Boolean]
        def skip_dir?(name)
          name.start_with?('.') || name == 'System Volume Information'
        end

        # Checks whether we or not we should skip a file by it's basename
        # Expects the file's basename only.
        # @param name [String]
        # @return [Boolean]
        def skip_file?(name)
          # including .DS_STORE files in particular
          # .filepart files are incomplete WinSCP uploads
          # .partial files are incomplete rclone uploads (as of version 1.63.0)
          name.start_with?('.') || name == 'Thumbs.db' || name.ends_with?('.filepart') || name.ends_with?('.partial')
        end

        # Checks whether or not we should skip a directory or file
        # by checking each fragment of the path with either {skip_dir?} or
        # {skip_file?}
        # Expects a path.
        # @param name [String]
        # @return [Boolean]
        def skip_path?(path)
          dir, basename = File.split(path)

          skip_file?(basename) || dir&.split('/')&.any? { |d| skip_dir?(d) }
        end
      end
    end
  end
end
