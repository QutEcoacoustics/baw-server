# frozen_string_literal: true

module Internal
  # A controller dedicated to responding to webhooks from sftpgo
  # https://github.com/drakkan/sftpgo/blob/main/docs/custom-actions.md
  # ensure the sftpgo config is setup to send web hooks to /sftpgo/hook
  class SftpgoController < Internal::InternalControllerBase
    # POST /internal/sftpgo/hook
    def hook
      allowed_params = params.require(:sftpgo).permit(*SftpgoClient::HookPayload.attribute_names)
      # Rails.logger.debug('allowed_params', allowed_params:, raw_post: request.raw_post, ip: request.ip)

      payload = SftpgoClient::HookPayload.new(allowed_params)
      case payload.action
      when SftpgoClient::HookPayload::ACTIONS_DOWNLOAD
        'hello'
      end

      # return no body
      head 200
    end
  end
end
