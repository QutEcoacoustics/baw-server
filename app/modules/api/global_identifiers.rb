# frozen_string_literal: true

module Api
  # A mixin to provide global identifiers for resources using a configured authority and a path.
  # Included in Api::UrlHelpers::Base.
  module GlobalIdentifiers
    # @param method [Symbol] the path helper method to generate the path for the resource
    # @param [...] arguments to be forwarded to the path helper method
    # @return [String] the global identifier for the resource, combining the authority and the path
    # @example
    #   Api::UrlHelpers.global_identifier(:audio_recording_path, id: 123) # => "example.org/audio_recordings/123"
    def global_identifier(method, ...)
      path = send(method, ...)
      "#{Settings.global_identifiers.authority}#{path}"
    end
  end
end
