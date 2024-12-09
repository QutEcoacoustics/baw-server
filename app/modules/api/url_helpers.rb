# frozen_string_literal: true

module Api
  # @example Usage
  #   include UrlHelpers
  #   url_helpers.posts_url # returns https://blabla.com/posts
  # @example Usage
  #   UrlHelpers.posts_url # returns https://blabla.com/posts
  module UrlHelpers
    # from http://stackoverflow.com/questions/16720514/how-to-use-url-helpers-in-lib-modules-and-set-host-for-multiple-environments
    extend ActiveSupport::Concern

    class Base
      # @return [Module]
      include Rails.application.routes.url_helpers

      include Api::CustomUrlHelpers

      def default_url_options
        ActionMailer::Base.default_url_options
      end
    end

    def url_helpers
      @url_helpers ||= UrlHelpers::Base.new
    end

    def self.method_missing(method, ...)
      @url_helpers ||= UrlHelpers::Base.new

      return @url_helpers if method == :url_helpers

      if @url_helpers.respond_to?(method)
        @url_helpers.send(method, ...)
      else
        # calls method in class this was include into.
        super
      end
    end

    def self.respond_to_missing?(method, include_private = false)
      @url_helpers ||= UrlHelpers::Base.new

      @url_helpers.respond_to?(method, include_private) || super
    end
  end
end
