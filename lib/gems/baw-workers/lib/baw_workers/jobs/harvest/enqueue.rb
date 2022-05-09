# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      module Enqueue
        module_function

        include SemanticLogger::Loggable

        # Enqueue multiple files for harvesting.
        # @param [String] to_do_path
        # @param [Boolean] is_real_run
        def scan(to_do_path, is_real_run)
          # setup
          logger.info('Scanning files', path: to_do_path, dry_run: is_real_run)

          default_user_id = User.find_by(roles_mask: User.mask_for([:harvester]))&.id

          raise("Can't find harvest user") if default_user_id.nil?

          to_do_path = validate_to_do_dir(to_do_path)

          gather_files = create_gather_files

          file_hashes = gather_files.run(to_do_path.to_s)

          results = file_hashes.map { |file_hash|
            path = file_hash[:file_rel_path]
            # if item exists, we know about it, no need to add it again
            # TODO: kick off a job again if needed?
            result = nil
            if check_if_harvest_item_exists(path)
              item = HarvestItem.find_by!(path:)
              if is_real_run
                result = try_again(path, item)
              else
                logger.info('Would retry harvesting', path:)
              end
            elsif is_real_run
              result = enqueue_file(path, info: file_hash, default_user_id:, harvest_id: nil)
            else
              logger.info('Would enqueue', path:)

            end

            { info: file_hash, result: }
          }

          summary = action_summary(results)

          logger.info do
            {
              message: "Summary of harvest #{is_real_run ? 'real run' : 'dry run'} for #{to_do_path}:",
              summary:,
              total: results.count
            }
          end

          { results:, path: to_do_path, summary: }
        end

        def check_if_harvest_item_exists(path)
          item = HarvestItem.exists?(path:)

          return false if item == false

          true
        end

        # create a new harvest item and job to process it
        def enqueue_file(rel_path, info:, default_user_id:, harvest_id:)
          item = new_harvest_item(rel_path, info, default_user_id, harvest_id)

          success = item.save
          id = item&.id
          logger.debug('harvest item save', path: rel_path, id:, success:)

          return false unless success

          result = BawWorkers::Jobs::Harvest::Action.perform_later(item.id, rel_path)
          success = result != false
          logger.debug('Enqueuing file', path: rel_path, id:, success:, job_id: (result || nil)&.job_id)

          success
        end

        def try_again(rel_path, item)
          # ok, so our job status plugin will reject a new enqueue if there's a duplicate
          # job.
          # it will also allow us to re-enqueue if the duplicated job has a terminal status

          if item.status == HarvestItem::STATUS_COMPLETED
            logger.info(
              'will not attempt item again, it is completed',
              rel_path:,
              id: item.id,
              audio_recording_id: item.audio_recording_id
            )
            return false
          end

          job = BawWorkers::Jobs::Harvest::Action.new(item.id, rel_path)
          result = job.enqueue
          success = result != false
          logger.info(
            'retrying harvest job',
            rel_path:,
            id: item.id,
            audio_recording_id: item.audio_recording_id,
            success:,
            unique: job.unique?
          )
          success
        end

        def new_harvest_item(rel_path, _info, id, harvest_id)
          # sanity check
          raise ArgumentError, "#{root_to_do_path}/#{path} does not exist" unless (root_to_do_path / rel_path).exist?

          # don't store any info, we're going to recalculate it all on dequeue anyway
          HarvestItem.new(path: rel_path, status: HarvestItem::STATUS_NEW, uploader_id: id, info: {}, harvest_id:)
        end

        # @return [Pathname]
        def root_to_do_path
          Settings.root_to_do_path
        end

        def validate_to_do_dir(path)
          to_do_path = root_to_do_path
          path = Pathname(path).realpath

          raise ArgumentError, "harvest path `#{path}` does not exist" unless path.exist?
          raise ArgumentError, "harvest path `#{path}` is not a directory" unless path.directory?

          is_child = path.to_s.start_with?(to_do_path.to_s)
          unless is_child
            raise ArgumentError,
              "harvest path `#{path}` is not a child of harvester to_do_path `#{to_do_path}`"
          end

          path
        end

        def action_summary(results)
          summary = {}

          results.each do |result|
            r = result[:result]
            file_info = result[:info]

            if file_info.blank?
              logger.warn {
                "Incomplete info from base dir '#{base_path}' for '#{file_info}'."
              }
            else
              file_ext = file_info[:extension].to_s
              relative_dir = Pathname(file_info[:file_rel_path]).dirname.to_s

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

        # @return [BawWorkers::Jobs::Harvest::GatherFiles]
        def create_gather_files
          config_file_name = Settings.actions.harvest.config_file_name
          valid_audio_formats = Settings.available_formats.to_h.values.flatten

          BawWorkers::Jobs::Harvest::GatherFiles.new(
            SemanticLogger[GatherFiles],
            BawWorkers::Config.file_info,
            valid_audio_formats,
            config_file_name,
            to_do_root: root_to_do_path
          )
        end
      end
    end
  end
end
