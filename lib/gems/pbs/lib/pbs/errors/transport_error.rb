# frozen_string_literal: true

module PBS
  module Errors
    # Any error raised while attempting to communicate with the PBS head node
    # over the specified transport (currently only SSH).
    class TransportError < PBSError
    end
  end
end
