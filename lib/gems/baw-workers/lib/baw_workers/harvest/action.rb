# frozen_string_literal: true

module BawWorkers
  module Harvest
    # Harvests audio files to be accessible via baw-server.
    class Action < BawWorkers::ActionBase
      class << self
        # Get the queue for this action. Used by Resque.
        # @return [Symbol] The queue.
        def queue
          Settings.actions.harvest.queue
        end

        # Perform work. Used by Resque.
        # @param [Hash] harvest_params
        # @return [Array<Hash>] array of hashes representing operations performed
        def action_perform(harvest_params)
          action_run(harvest_params, true)
        end

        # Perform work. Used by Resque.
        # @param [Hash] harvest_params
        # @param [Boolean] is_real_run
        # @return [Array<Hash>] array of hashes representing operations performed
        def action_run(harvest_params, is_real_run)
          BawWorkers::Config.logger_worker.info(name) do
            "Started harvest #{is_real_run ? 'real run' : 'dry run'} using '#{harvest_params}'."
          end

          begin
            copy_on_success = false
            if harvest_params.include?(:copy_on_success)
              copy_on_success = harvest_params[:copy_on_success]
            elsif harvest_params.include?('copy_on_success')
              copy_on_success = harvest_params['copy_on_success']
            end

            result = action_single_file.run(harvest_params, is_real_run, copy_on_success)
          rescue StandardError => e
            BawWorkers::Config.logger_worker.error(name) { e }
            BawWorkers::Mail::Mailer.send_worker_error_email(
              BawWorkers::Harvest::Action,
              harvest_params,
              queue,
              e
            )
            raise e
          end

          BawWorkers::Config.logger_worker.info(name) do
            "Completed harvest with result '#{result}'."
          end

          result
        end

        # Harvest specified folder.
        # @param [String] to_do_path
        # @param [Boolean] is_real_run
        # @param [Boolean] copy_on_success
        # @return [Hash] array of hashes representing operations performed
        def action_perform_rake(to_do_path, is_real_run, copy_on_success = false)
          # returns results from action_gather_and_process
          action_gather_and_process(to_do_path, is_real_run, copy_on_success) do |file_hash|
            BawWorkers::Harvest::Action.action_run(file_hash, is_real_run) if is_real_run
          end
        end

        # Enqueue a single file for harvesting.
        # @param [Hash] harvest_params
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def action_enqueue(harvest_params)
          result = BawWorkers::Harvest::Action.create(harvest_params: harvest_params)
          BawWorkers::Config.logger_worker.info(name) do
            "Job enqueue returned '#{result}' using #{harvest_params}."
          end
          result
        end

        # Enqueue multiple files for harvesting.
        # @param [String] to_do_path
        # @param [Boolean] is_real_run
        # @param [Boolean] copy_on_success
        # @return [Array<Hash>] array of hashes representing operations performed
        def action_enqueue_rake(to_do_path, is_real_run, copy_on_success = false)
          # returns results from action_gather_and_process
          action_gather_and_process(to_do_path, is_real_run, copy_on_success) do |file_hash|
            BawWorkers::Harvest::Action.action_enqueue(file_hash) if is_real_run
          end
        end

        # Create a BawWorkers::Harvest::GatherFiles instance.
        # @return [BawWorkers::Harvest::GatherFiles]
        def action_gather_files
          config_file_name = Settings.actions.harvest.config_file_name
          valid_audio_formats = Settings.available_formats.audio + Settings.available_formats.audio_decode_only

          BawWorkers::Harvest::GatherFiles.new(
            BawWorkers::Config.logger_worker,
            BawWorkers::Config.file_info,
            valid_audio_formats,
            config_file_name
          )
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

          BawWorkers::Config.logger_worker.debug(name) do
            "Full results: #{results}"
          end

          summary = {}

          files.each do |file|
            file_info = file[:info]

            if file_info.blank?
              BawWorkers::Config.logger_worker.warn(name) {
                "Incomplete info from base dir '#{base_path}' for '#{file_info}'."
              }
            else
              file_dir = File.dirname(file_info[:file_path]).to_s
              file_ext = file_info[:extension].to_s
              relative_dir = Pathname.new(file_dir).relative_path_from(base_path).to_s

              summary[relative_dir] = {} unless summary.include?(relative_dir)

              summary[relative_dir][file_ext] = 0 unless summary[relative_dir].include?(file_ext)
              summary[relative_dir][file_ext] += 1

              summary[relative_dir]['project_id'] = [] unless summary[relative_dir].include?('project_id')
              unless summary[relative_dir]['project_id'].include?(file_info[:project_id].to_i)
                summary[relative_dir]['project_id'].push(file_info[:project_id].to_i)
              end

              summary[relative_dir]['site_id'] = [] unless summary[relative_dir].include?('site_id')
              unless summary[relative_dir]['site_id'].include?(file_info[:site_id].to_i)
                summary[relative_dir]['site_id'].push(file_info[:site_id].to_i)
              end

              summary[relative_dir]['uploader_id'] = [] unless summary[relative_dir].include?('uploader_id')
              unless summary[relative_dir]['uploader_id'].include?(file_info[:uploader_id].to_i)
                summary[relative_dir]['uploader_id'].push(file_info[:uploader_id].to_i)
              end

              summary[relative_dir]['utc_offset'] = [] unless summary[relative_dir].include?('utc_offset')
              unless summary[relative_dir]['utc_offset'].include?(file_info[:utc_offset])
                summary[relative_dir]['utc_offset'].push(file_info[:utc_offset])
              end

            end
          end

          summary
        end

        def action_gather_and_process(to_do_path, is_real_run, copy_on_success = false)
          gather_files = action_gather_files
          file_hashes = gather_files.run(to_do_path)

          results = { path: to_do_path, results: [] }

          file_hashes.each do |file_hash|
            file_hash[:copy_on_success] = copy_on_success

            result = (yield file_hash if block_given?)

            results[:results].push({ info: file_hash, result: result })
          end

          summary = action_summary(results)

          BawWorkers::Config.logger_worker.info(name) do
            "Summary of harvest #{is_real_run ? 'real run' : 'dry run'} for #{to_do_path}: #{summary.to_json}"
          end

          { results: results[:results], path: to_do_path, summary: summary }
        end
      end

      def perform_options_keys
        ['harvest_params']
      end

      # Produces a sensible name for this payload.
      # Should be unique but does not need to be. Has no operational effect.
      # This value is only used when the status is updated by resque:status.
      def name
        hp = @options['harvest_params']
        "Harvest for: #{hp['file_name']}, data_length_bytes=#{hp['data_length_bytes']}, site_id=#{hp['site_id']}"
      end
    end
  end
end
