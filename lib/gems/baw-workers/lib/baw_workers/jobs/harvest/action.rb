# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      # Harvests audio files to be accessible via baw-server.
      class Action < BawWorkers::Jobs::ApplicationJob
        # Get the queue for this action. Used by Resque.
        # @return [Symbol] The queue.
        queue_as Settings.actions.harvest.queue
        perform_expects Integer, String

        # Perform work. Used by Resque.
        # @param [Integer] harvest_id
        # @param [String] harvest_path
        # @return [Array<Hash>] array of hashes representing operations performed
        def perform(harvest_id, rel_path)
          item = HarvestItem.find(harvest_id)

          action_run(item, rel_path)
        end

        # @return [Array<Hash>] array of hashes representing operations performed
        def action_run(item, path)
          real_path = Enqueue.root_to_do_path / path
          item.info ||= {}

          logger.info('Started harvest')

          begin
            # get the basic info from the file again

            gather_files = Enqueue.create_gather_files
            # TODO: this will need to be fixed, root to do path allows a job to get harvest.ymls for files outside
            # of the scope for which it was enqueued
            file_info = gather_files.file(real_path, Enqueue.root_to_do_path, {})
            item.info[:file_info] = file_info

            unless file_info.values_at(:project_id, :site_id, :uploader_id).all?
              raise BawWorkers::Exceptions::HarvesterError,
                    'Missing one or more values for :project_id, :site_id, or :uploader_id'
            end

            result = action_single_file.run(file_info, true, false, harvest_item: item)
          rescue StandardError => e
            logger.error(name, exception: e)

            item.info[:error] = e.message
            item.status = one_of_our_exceptions(e) ? 'failed' : 'error'
            item.save!
            failed!(e.message)
          end

          logger.info('Completed harvest', result: result)
          item.info[:error] = nil
          item.status = 'completed'
          item.save
          result
        end

        def one_of_our_exceptions(error)
          return true if error.class.name =~ /BawAudioTools::Exceptions/
          return true if error.class.name =~ /BawWorkers::Exceptions/

          # more to come
          false
        end

        # # Harvest specified folder.
        # # @param [String] to_do_path
        # # @param [Boolean] is_real_run
        # # @param [Boolean] copy_on_success
        # # @return [Hash] array of hashes representing operations performed
        # def self.action_perform_rake(to_do_path, is_real_run, copy_on_success = false)
        #   # returns results from action_gather_and_process
        #   action_gather_and_process(to_do_path, is_real_run, copy_on_success) do |file_hash|
        #     BawWorkers::Jobs::Harvest::Action.action_run(file_hash, is_real_run) if is_real_run
        #   end
        # end

        # Enqueue a single file for harvesting.
        # @param [Hash] harvest_params
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def self.action_enqueue(harvest_params)
          result = BawWorkers::Jobs::Harvest::Action.create(harvest_params: harvest_params)
          BawWorkers::Config.logger_worker.info(name) do
            "Job enqueue returned '#{result}' using #{harvest_params}."
          end
          result
        end

        # Enqueue multiple files for harvesting.
        # # @param [String] to_do_path
        # # @param [Boolean] is_real_run
        # # @param [Boolean] copy_on_success
        # # @return [Array<Hash>] array of hashes representing operations performed
        # def self.action_enqueue_rake(to_do_path, is_real_run, copy_on_success = false)
        #   # returns results from action_gather_and_process
        #   action_gather_and_process(to_do_path, is_real_run, copy_on_success) do |file_hash|
        #     BawWorkers::Jobs::Harvest::Action.perform_later!(file_hash) if is_real_run
        #   end
        # end

        # Create a BawWorkers::Jobs::Harvest::GatherFiles instance.
        # @return [BawWorkers::Jobs::Harvest::GatherFiles]
        # def self.action_gather_files
        #   config_file_name = Settings.actions.harvest.config_file_name
        #   valid_audio_formats = Settings.available_formats.audio + Settings.available_formats.audio_decode_only

        #   BawWorkers::Jobs::Harvest::GatherFiles.new(
        #     BawWorkers::Config.logger_worker,
        #     BawWorkers::Config.file_info,
        #     valid_audio_formats,
        #     config_file_name
        #   )
        # end

        # Create a BawWorkers::Jobs::Harvest::SingleFile instance.
        # @return [BawWorkers::Jobs::Harvest::SingleFile]
        def action_single_file
          BawWorkers::Jobs::Harvest::SingleFile.new(
            BawWorkers::Config.logger_worker,
            BawWorkers::Config.file_info,
            BawWorkers::Config.api_communicator,
            BawWorkers::Config.original_audio_helper
          )
        end

        # def self.action_summary(results)
        #   base_path = Pathname.new(results[:path])
        #   files = results[:results]

        #   BawWorkers::Config.logger_worker.debug(name) do
        #     "Full results: #{results}"
        #   end

        #   summary = {}

        #   files.each do |file|
        #     file_info = file[:info]

        #     if file_info.blank?
        #       BawWorkers::Config.logger_worker.warn(name) {
        #         "Incomplete info from base dir '#{base_path}' for '#{file_info}'."
        #       }
        #     else
        #       file_dir = File.dirname(file_info[:file_path]).to_s
        #       file_ext = file_info[:extension].to_s
        #       relative_dir = Pathname.new(file_dir).relative_path_from(base_path).to_s

        #       summary[relative_dir] = {} unless summary.include?(relative_dir)

        #       summary[relative_dir][file_ext] = 0 unless summary[relative_dir].include?(file_ext)
        #       summary[relative_dir][file_ext] += 1

        #       summary[relative_dir]['project_id'] = [] unless summary[relative_dir].include?('project_id')
        #       unless summary[relative_dir]['project_id'].include?(file_info[:project_id].to_i)
        #         summary[relative_dir]['project_id'].push(file_info[:project_id].to_i)
        #       end

        #       summary[relative_dir]['site_id'] = [] unless summary[relative_dir].include?('site_id')
        #       unless summary[relative_dir]['site_id'].include?(file_info[:site_id].to_i)
        #         summary[relative_dir]['site_id'].push(file_info[:site_id].to_i)
        #       end

        #       summary[relative_dir]['uploader_id'] = [] unless summary[relative_dir].include?('uploader_id')
        #       unless summary[relative_dir]['uploader_id'].include?(file_info[:uploader_id].to_i)
        #         summary[relative_dir]['uploader_id'].push(file_info[:uploader_id].to_i)
        #       end

        #       summary[relative_dir]['utc_offset'] = [] unless summary[relative_dir].include?('utc_offset')
        #       unless summary[relative_dir]['utc_offset'].include?(file_info[:utc_offset])
        #         summary[relative_dir]['utc_offset'].push(file_info[:utc_offset])
        #       end

        #     end
        #   end

        #   summary
        # end

        # def self.action_gather_and_process(to_do_path, is_real_run, copy_on_success = false)
        #   gather_files = action_gather_files
        #   file_hashes = gather_files.run(to_do_path)

        #   results = { path: to_do_path, results: [] }

        #   file_hashes.each do |file_hash|
        #     file_hash[:copy_on_success] = copy_on_success

        #     result = (yield file_hash if block_given?)

        #     results[:results].push({ info: file_hash, result: result })
        #   end

        #   summary = action_summary(results)

        #   BawWorkers::Config.logger_worker.info(name) do
        #     "Summary of harvest #{is_real_run ? 'real run' : 'dry run'} for #{to_do_path}: #{summary.to_json}"
        #   end

        #   { results: results[:results], path: to_do_path, summary: summary }
        # end

        # Produces a sensible name for this payload.
        # Should be unique but does not need to be. Has no operational effect.
        # This value is only used when the status is updated by resque:status.
        def name
          id, path = arguments
          "HarvestItem(#{id}) for: #{path}"
        end

        def create_job_id
          # duplicate jobs should be detected
          ::BawWorkers::ActiveJob::Identity::Generators.generate_hash_id(self, 'harvest_job')
        end
      end
    end
  end
end
