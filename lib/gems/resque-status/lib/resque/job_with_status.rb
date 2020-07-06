# frozen_string_literal: true

module Resque
  class JobWithStatus
    include Resque::Plugins::Status
  end
end
