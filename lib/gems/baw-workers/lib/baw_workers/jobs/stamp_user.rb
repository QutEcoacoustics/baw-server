# frozen_string_literal: true

module BawWorkers
  module Jobs
    # Set the current user as the harvester user.
    # Not our default because many jobs are read only and avoiding the extra
    # database call is a good thing.
    module StampUser
      extend ActiveSupport::Concern

      included do
        around_perform :set_then_reset_user_stamper
      end

      def set_then_reset_user_stamper
        User.stamper = User.harvester_user
        yield
      ensure
        User.stamper = nil
      end
    end
  end
end
