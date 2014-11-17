module BawWorkers
  module Media
    # Cuts audio files and generates spectrograms.
    class Action

      # Ensure that there is only one job with the same payload per queue.
      # The default method to create a job ID from these parameters is to
      # do some normalization on the payload and then md5'ing it
      include Resque::Plugins::UniqueJob

      # a set of keys starting with 'stats:jobs:queue_name' inside your Resque redis namespace
      # Jobs performed
      # Jobs enqueued
      # Jobs failed
      # Duration of last x jobs completed
      # Average job duration over last 100 jobs completed
      # Longest job duration over last 100 jobs completed
      # Jobs enqueued as timeseries data (minute, hour, day)
      # Jobs performed as timeseries data (minute, hour, day)
      extend Resque::Plugins::JobStats

      # track specific job instances and their status.
      # resque-status achieves this by giving job instances UUID's
      # and allowing the job instances to report their
      # status from within their iterations.
      include Resque::Plugins::Status

      # include common methods
      # must be the last include/extend so it can override methods
      include BawWorkers::ActionCommon

      class << self

        # By default, lock_after_execution_period is 0 and enqueued? becomes
        # false as soon as the job is being worked on.
        # The lock_after_execution_period setting can be used to delay when
        # the unique job key is deleted (i.e. when enqueued? becomes false).
        # For example, if you have a long-running unique job that takes around
        # 10 seconds, and you don't want to requeue another job until you are
        # sure it is done, you could set lock_after_execution_period = 20.
        # Or if you never want to run a long running job more than once per
        # minute, set lock_after_execution_period = 60.
        # @return [Fixnum]
        def lock_after_execution_period
          30
        end

        # Get the queue for this action. Used by Resque. Overrides resque-status class method.
        # @return [Symbol] The queue.
        def queue
          BawWorkers::Settings.actions.media.queue
        end

        # Perform work. Used by Resque.
        # @param [Symbol] media_type
        # @param [Hash] media_request_params
        # @return [Array<String>] target existing paths
        def action_perform(media_type, media_request_params)
          begin
            media_type_sym, params_sym = action_validate(media_type, media_request_params)
            result = make_media_request(media_type_sym, params_sym)
          rescue Exception => e
            BawWorkers::Config.logger_worker.error(self.name) { e }
            BawWorkers::Mail::Mailer.send_worker_error_email(
                BawWorkers::Media::Action,
                {media_type: media_type, media_request_params: media_request_params},
                queue,
                e
            )
            raise e
          end

          result
        end

        # Enqueue a media processing request.
        # @param [Symbol] media_type
        # @param [Hash] media_request_params
        # @return [void]
        def action_enqueue(media_type, media_request_params)
          media_type_sym, params_sym = action_validate(media_type, media_request_params)
          #Resque.enqueue(BawWorkers::Media::Action, media_type_sym, params_sym)
          result = BawWorkers::Media::Action.create(media_type: media_type_sym, media_request_params: params_sym)
          BawWorkers::Config.logger_worker.info(self.name) {
            "Job enqueue returned '#{result}' using type #{media_type} with #{media_request_params}."
          }
          result
        end

        # Get the available media types this action can create.
        # @return [Array<Symbol>] The available media types.
        def valid_media_types
          [:audio, :spectrogram]
        end

        # Get helper class instance.
        # @return [BawWorkers::Media::WorkHelper]
        def action_helper
          BawWorkers::Media::WorkHelper.new(
              BawWorkers::Config.audio_helper,
              BawWorkers::Config.spectrogram_helper,
              BawWorkers::Config.original_audio_helper,
              BawWorkers::Config.audio_cache_helper,
              BawWorkers::Config.spectrogram_cache_helper,
              BawWorkers::Config.file_info,
              BawWorkers::Config.logger_worker,
              BawWorkers::Config.temp_dir
          )
        end

        # Create specified media type by applying media request params.
        # @param [Symbol] media_type
        # @param [Hash] media_request_params
        # @return [Array<String>] target existing paths
        def make_media_request(media_type, media_request_params)
          media_type_sym, params_sym = action_validate(media_type, media_request_params)

          params_sym[:datetime_with_offset] = BawWorkers::Validation.check_datetime(params_sym[:datetime_with_offset])

          target_existing_paths = []
          case media_type_sym
            when :audio
              target_existing_paths = action_helper.create_audio_segment(params_sym)
            when :spectrogram
              target_existing_paths = action_helper.generate_spectrogram(params_sym)
            else
              BawWorkers::Validation.validate_contains(media_type_sym, valid_media_types)
          end

          BawWorkers::Config.logger_worker.info(self.name) {
            "Created cache files #{media_type}: #{target_existing_paths}."
          }

          target_existing_paths
        end

        def action_validate(media_type, media_request_params)
          BawWorkers::Validation.validate_hash(media_request_params)
          media_type_sym = media_type.to_sym
          params_sym = BawWorkers::Validation.deep_symbolize_keys(media_request_params)
          BawWorkers::Validation.validate_contains(media_type_sym, valid_media_types)
          [media_type_sym, params_sym]
        end


      end

      # Perform method used by resque-status.
      def perform
        media_type = options['media_type']
        media_request_params = options['media_request_params']
        self.class.action_perform(media_type, media_request_params)
      end

    end
  end
end