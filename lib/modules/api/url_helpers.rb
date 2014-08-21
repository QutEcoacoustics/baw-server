# from http://stackoverflow.com/questions/16720514/how-to-use-url-helpers-in-lib-modules-and-set-host-for-multiple-environments
# usage:
# include UrlHelpers
# url_helpers.posts_url # returns https://blabla.com/posts
# or
# UrlHelpers.posts_url # returns https://blabla.com/posts
module Api
  module UrlHelpers

    extend ActiveSupport::Concern

    class Base
      include Rails.application.routes.url_helpers

      def default_url_options
        ActionMailer::Base.default_url_options
      end
    end

    def url_helpers
      @url_helpers ||= UrlHelpers::Base.new
    end

    def self.method_missing(method, *args, &block)
      @url_helpers ||= UrlHelpers::Base.new

      if @url_helpers.respond_to?(method)
        @url_helpers.send(method, *args, &block)
      else
        # calls method in class this was include into.
        super method, *args, &block
      end
    end
  end
end