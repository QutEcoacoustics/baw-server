# frozen_string_literal: true

module Internal
  # A controller dedicated to responding to webhooks from sftpgo
  # https://github.com/drakkan/sftpgo/blob/main/docs/custom-actions.md
  # ensure the sftpgo config is setup to send web hooks to /sftpgo/hook
  class SftpgoController < Internal::InternalControllerBase
    include SftpgoClient

    REDIS_DEBUG_KEY = 'baw::debug::SftpgoController::sftpgo_hook_called'
    around_action :profile_hook, if: -> { BawApp.dev_or_test? }

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

    def profile_hook(&block)
      # during tests, it is particularly hard to keep track of when
      # hooks are called. So we use redis to mark when it happens.

      yield block
    ensure
      BawWorkers::Config.redis_communicator.set(
        REDIS_DEBUG_KEY,
        true
      )
    end

    def load_harvest(payload)
      @harvest = Harvest.fetch_harvest_from_absolute_path(payload.path)
      # no harvest found for the described path
      return false if @harvest.nil?

      true
    end

    def load_harvest_item(payload)
      item_path = @harvest.harvester_relative_path(payload.virtual_path)
      @harvest_item = HarvestItem.find_by_path_and_harvest(item_path, @harvest)
    end

    # @param payload [::SftpgoClient::HookPayload]
    def enqueue_harvest_job_for_upload(payload)
      return unless load_harvest(payload)

      BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(
        @harvest,
        @harvest.harvester_relative_path(payload.virtual_path),
        # if we're doing a steaming harvest immediately try to harvest
        # otherwise assume we're just gathering metadata
        should_harvest: @harvest.streaming_harvest?
      )
    end

    # @param payload [::SftpgoClient::HookPayload]
    def remove_harvest_item(payload)
      return unless load_harvest(payload)

      load_harvest_item(payload)

      return if @harvest_item.nil?

      # we're only trying to prevent work here for things we haven't gathered information about
      # if we've processed the file in any way, we can't delete the harvest_item
      unless @harvest_item.new?
        @harvest_item.file_deleted = true
        @harvest_item.save!
        return
      end

      logger.debug('Deleting harvest item', path: @harvest_item.path)
      @harvest_item.delete!
    end

    # @param payload [::SftpgoClient::HookPayload]
    def rename_harvest_item(payload)
      return unless load_harvest(payload)

      load_harvest_item(payload)

      return if @harvest_item.nil?

      new_path = harvest.harvester_relative_path(payload.virtual_target_path)

      logger.debug('Updating harvest item path', old_path: @harvest_item.path, new_path:)
      @harvest_item.path = new_path
      @harvest_item.save!
    end
  end
end
