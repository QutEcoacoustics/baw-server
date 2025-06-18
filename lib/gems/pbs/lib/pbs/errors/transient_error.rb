# frozen_string_literal: true

module PBS
  module Errors
    # Indicates a failure to execute a PBS command that could be resolved by retrying the command.
    class TransientError < PBSError; end
  end
end
