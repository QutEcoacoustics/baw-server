# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Media
      # base class for media jobs
      class MediaJob < BawWorkers::Jobs::ApplicationJob
        queue_as Settings.actions.media.queue

        def cache_to_redis?
          Settings.actions.media.cache_to_redis
        end

        protected

        # Get helper class instance.
        # @return [BawWorkers::Media::WorkHelper]
        def action_helper
          BawWorkers::Jobs::Media::WorkHelper.new(
            BawWorkers::Config.audio_helper,
            BawWorkers::Config.spectrogram_helper,
            BawWorkers::Config.original_audio_helper,
            BawWorkers::Config.audio_cache_helper,
            BawWorkers::Config.spectrogram_cache_helper,
            BawWorkers::Config.file_info,
            logger,
            BawWorkers::Config.temp_dir
          )
        end

        # Upload files to a redis cache as a shortcut mechanism for sometimes
        # slow network storage caches. Will squash errors!
        # @param [Array<Pathname,String>] paths to upload
        # @return [Boolean] true if successful, nil if not attempted
        def redis_cache_upload(paths)
          return nil unless cache_to_redis?

          success = paths.each { |path|
            path = Pathname(path)
            BawWorkers::Config.redis_communicator.set_file(
              path.basename,
              path
            )
          }

          success.all?
        rescue StandardError => e
          logger.error('Failed to upload, error suppressed', exception: e, paths: paths)
          false
        end
      end
    end
  end
end
