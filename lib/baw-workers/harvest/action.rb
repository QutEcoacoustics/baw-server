module BawWorkers
  module Harvest
    # Harvests audio files to be accessible via baw-server.
    class Action

      # Ensure that there is only one job with the same payload per queue.
      include Resque::Plugins::UniqueJob

      # a set of keys starting with 'stats:jobs:queue_name' inside your Resque redis namespace
      extend Resque::Plugins::JobStats

      # track specific job instances and their status
      include Resque::Plugins::Status

      # include common methods
      include BawWorkers::ActionCommon

      # All methods do not require a class instance.
      class << self

        # Delay when the unique job key is deleted (i.e. when enqueued? becomes false).
        # @return [Fixnum]
        def lock_after_execution_period
          30
        end

        # Get the queue for this action. Used by Resque.
        # @return [Symbol] The queue.
        def queue
          BawWorkers::Settings.actions.harvest.queue
        end

        # Perform work. Used by Resque.
        # @param [Hash] harvest_params
        # @return [Array<Hash>] array of hashes representing operations performed
        def action_perform(harvest_params)
          action_run(harvest_params, false)
        end

        # Perform work. Used by Resque.
        # @param [Hash] harvest_params
        # @param [Boolean] is_real_run
        # @return [Array<Hash>] array of hashes representing operations performed
        def action_run(harvest_params, is_real_run)

          BawWorkers::Config.logger_worker.info(self.name) {
            "Started harvest #{is_real_run ? 'real run' : 'dry run' } using '#{harvest_params}'."
          }

          begin
            result = action_single_file.run(harvest_params, is_real_run)
          rescue Exception => e
            BawWorkers::Config.logger_worker.error(self.name) { e }
            BawWorkers::Mail::Mailer.send_worker_error_email(
                BawWorkers::Harvest::Action,
                harvest_params,
                queue,
                e
            )
            raise e
          end

          BawWorkers::Config.logger_worker.info(self.name) {
            "Completed harvest with result '#{result}'."
          }

          result
        end

        # Harvest specified folder.
        # @param [String] to_do_path
        # @param [Boolean] is_real_run
        # @return [Hash] array of hashes representing operations performed
        def action_perform_rake(to_do_path, is_real_run)
          gather_files = action_gather_files
          file_hashes = gather_files.run(to_do_path)

          # list the directories and file extensions in each directory

          results = {path: to_do_path, results: []}
          file_hashes.each do |file_hash|
            result = BawWorkers::Harvest::Action.action_run(file_hash, is_real_run) if is_real_run
            results[:results].push({file_info: file_hash, result: result})
          end

          summary = action_summary(results)
          BawWorkers::Config.logger_worker.info(self.name) {
            "Summary: #{summary}"
          }

          results
        end

        # Enqueue a single file for harvesting.
        # @param [Hash] harvest_params
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def action_enqueue(harvest_params)
          result = BawWorkers::Harvest::Action.create(harvest_params: harvest_params)
          BawWorkers::Config.logger_worker.info(self.name) {
            "Job enqueue returned '#{result}' using #{harvest_params}."
          }
          result
        end

        # Enqueue multiple files for harvesting.
        # @param [String] to_do_path
        # @param [Boolean] is_real_run
        # @return [Array<Hash>] array of hashes representing operations performed
        def action_enqueue_rake(to_do_path, is_real_run)
          gather_files = action_gather_files
          file_hashes = gather_files.run(to_do_path)

          results = {path: to_do_path, results: []}


            file_hashes.each do |file_hash|
              result = nil
              result = BawWorkers::Harvest::Action.action_enqueue(file_hash) if is_real_run
              results[:results].push({file_hash: file_hash, result: result})
            end

          summary = action_summary(results)
          BawWorkers::Config.logger_worker.info(self.name) {
            "Summary: #{summary}"
          }

          results
        end

        # Create a BawWorkers::Harvest::GatherFiles instance.
        # @return [BawWorkers::Harvest::GatherFiles]
        def action_gather_files
          config_file_name = BawWorkers::Settings.actions.harvest.config_file_name
          valid_audio_formats = BawWorkers::Settings.available_formats.audio

          BawWorkers::Harvest::GatherFiles.new(
              BawWorkers::Config.logger_worker,
              BawWorkers::Config.file_info,
              valid_audio_formats,
              config_file_name)
        end

        # Create a BawWorkers::Harvest::SingleFile instance.
        # @return [BawWorkers::Harvest::SingleFile]
        def action_single_file
          BawWorkers::Harvest::SingleFile.new(
              BawWorkers::Config.logger_worker,
              BawWorkers::Config.file_info,
              BawWorkers::Config.api_communicator,
              BawWorkers::Config.original_audio_helper
          )
        end

        def action_summary(results)
          base_path = Pathname.new(results[:path])
          files = results[:results]

          summary = {}

          files.each do |file|
            file_dir = File.dirname(file[:file_info][:file_path]).to_s
            file_ext = file[:file_info][:extension].to_s
            relative_dir = Pathname.new(file_dir).relative_path_from(base_path)

            summary[file_dir] = {} unless summary.include?(file_dir)
            summary[file_dir][file_ext] = 0 unless summary[file_dir].include?(file_ext)
            summary[file_dir][file_ext] += 1
          end

          summary
        end

      end

      # Perform method used by resque-status.
      def perform
        harvest_params = options['harvest_params']
        self.class.action_perform(harvest_params)
      end

    end
  end
end