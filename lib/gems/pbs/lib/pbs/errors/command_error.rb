# frozen_string_literal: true

module PBS
  module Errors
    # Indicates a failure to execute a PBS command that can not be resolved by retrying the command.
    class CommandError < PBSError; end
  end
end
