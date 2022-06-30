# frozen_string_literal: true

module Internal
  # Base class for internal controllers.
  # Internal controllers are use for micro-service endpoints,
  # typically webhooks that need some kind of different authentication mechanism.
  class InternalControllerBase < ApplicationController
    before_action :authenticate!

    # Internal routes authenticate by an allow list of IPs
    def authenticate!
      name = "internal_#{controller_name}"
      logger.info("#{name} authenticate!", ip: request.ip, remote_ip: request.remote_ip,
        http_forwarded_for: request.headers['HTTP_X_FORWARDED_FOR'])
      authorize! :manage, name.to_sym, request.remote_ip
    end
  end
end
