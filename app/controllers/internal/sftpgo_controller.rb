# frozen_string_literal: true

module Internal
  # A controller dedicated to responding to webhooks from sftpgo
  # https://github.com/drakkan/sftpgo/blob/main/docs/custom-actions.md
  # ensure the sftpgo config is setup to send web hooks to /sftpgo/hook
  class SftpgoController < Internal::InternalControllerBase
    include SftpgoClient

    # POST /internal/sftpgo/hook
    def hook
      allowed_params = params.require(:sftpgo).permit(*HookPayload.attribute_names)
      #Rails.logger.debug('sftpgo webhook', allowed_params:, raw_post: request.raw_post, ip: request.ip)

      payload = HookPayload.new(allowed_params)

      case payload.action
      when HookPayload::ACTIONS_UPLOAD
        enqueue_harvest_job_for_upload(payload)
      when HookPayload::ACTIONS_DELETE
        remove_harvest_item(payload)
      when HookPayload::ACTIONS_RENAME
        rename_harvest_item(payload)
      end

      # return no body
      no_body
    end

    private

    def no_body
      head 200
    end

    # @return [Harvest]
    attr_reader :harvest

    def load_harvest(payload)
      @harvest = Harvest.fetch_harvest_from_absolute_path(payload.path)

      # no harvest found for the described path
      return unless @harvest.nil?

      logger.error('No active harvest found for a sftpgo webhook', payload:)
      raise "No active harvest found for a sftpgo webhook: #{payload.to_json}"
    end

    # @return [HarvestItem]
    attr_reader :harvest_item

    def load_harvest_item(payload)
      item_path = harvest.harvester_relative_path(payload.virtual_path)
      @harvest_item = HarvestItem.find_by_path_and_harvest(item_path, @harvest)
    end

    # @param payload [::SftpgoClient::HookPayload]
    def enqueue_harvest_job_for_upload(payload)
      return if skip?(payload)

      load_harvest(payload)

      BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(
        harvest,
        harvest.harvester_relative_path(payload.virtual_path),
        # if we're doing a steaming harvest immediately try to harvest
        # otherwise assume we're just gathering metadata
        should_harvest: harvest.streaming_harvest?
      )
    end

    # @param payload [::SftpgoClient::HookPayload]
    def remove_harvest_item(payload)
      load_harvest(payload)

      load_harvest_item(payload)

      return if harvest_item.nil?

      # we're only trying to prevent work here for things we haven't completed
      # if it's completed then we can't delete the harvest_item
      if harvest_item.completed?
        harvest_item.file_deleted = true
        harvest_item.save!
        logger.debug('Marked harvest item\'s file as deleted', path: harvest_item.path)

        return
      end

      logger.debug('Deleting harvest item', path: harvest_item.path)
      harvest_item.destroy
    end

    # @param payload [::SftpgoClient::HookPayload]
    def rename_harvest_item(payload)
      return if skip?(payload)

      load_harvest(payload)

      load_harvest_item(payload)

      # if for some reason the harvest item doesn't exist, then act as if this is an upload hook
      # this is main path WinSCP uploads take, upload (which is ignored) and then rename.
      if harvest_item.nil?
        logger.debug('Harvest item not found, creating a new one', path: payload.virtual_target_path)

        modified_payload = payload.new(virtual_path: payload.virtual_target_path)
        return enqueue_harvest_job_for_upload(modified_payload)
      end

      new_path = harvest.harvester_relative_path(payload.virtual_target_path)

      logger.debug('Updating harvest item path', old_path: harvest_item.path, new_path:)
      harvest_item.path = new_path
      harvest_item.save!
    end

    # @param payload [::SftpgoClient::HookPayload]
    def skip?(payload)
      path = payload.virtual_target_path || payload.virtual_path
      BawWorkers::Jobs::Harvest::PathFilter.skip_file?(path)
    end
  end
end
