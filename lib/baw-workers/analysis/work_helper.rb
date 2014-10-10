module BawWorkers
  module Analysis
    class WorkHelper

      # include common methods
      include BawWorkers::Common

      def initialize(logger, is_dry_run = false)
        @logger = logger
        @is_dry_run = is_dry_run
      end

    end
  end
end