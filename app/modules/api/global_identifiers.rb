# frozen_string_literal: true

module Api
  # A mixin to provide global identifiers for resources using a configured authority.
  module GlobalIdentifiers
    def global_identifier(method, ...)
      path = send(method, ...)
      "#{Settings.global_identifiers.authority}#{path}"
    end
  end
end
