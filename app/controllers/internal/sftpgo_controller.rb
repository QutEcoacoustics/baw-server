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
      # Rails.logger.debug('allowed_params', allowed_params:, raw_post: request.raw_post, ip: request.ip)

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

    def load_harvest(payload)
      @harvest = Harvest.fetch_harvest_from_absolute_path(payload.path)
      # no harvest foud for the described path
      return false if @harvest.nil?

      item_path = @harvest.harvester_relative_path(payload.virtual_path)
      @harvest_item = HarvestItem.find_by_path_and_harvest(item_path, @harvest)

      true
    end

    # @param payload [::SftpgoClient::HookPayload]
    def enqueue_harvest_job_for_upload(payload)
      return unless load_harvest(payload)

      if @harvest_item.nil?
        # brand new, make a job
        BawWorkers::Jobs::Harvest::Enqueue.enqueue_file(
          @harvest_item.path,
          {},
          default_user_id: @harvest.creator_id,
          harvest_id: @harvest.id
        )
      else
        # try processing this file again
        BawWorkers::Jobs::Harvest::Enqueue.try_again(
          @harvest_item.path,
          @harvest_item
        )
      end
    end

    # @param payload [::SftpgoClient::HookPayload]
    def remove_harvest_item(payload)
      return unless load_harvest(payload)

      return if @harvest_item.nil?

      logger.debug('Deleting harvest item', path: @harvest_item.path)
      @harvest_item.delete!
    end

    # @param payload [::SftpgoClient::HookPayload]
    def rename_harvest_item(payload)
      return unless load_harvest(payload)

      return if @harvest_item.nil?

      new_path = harvest.harvester_relative_path(payload.virtual_target_path)

      logger.debug('Updating harvest item path', old_path: @harvest_item.path, new_path:)
      @harvest_item.path = new_path
      @harvest_item.save!
    end
  end
end
