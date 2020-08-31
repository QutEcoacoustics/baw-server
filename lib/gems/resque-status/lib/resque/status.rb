# frozen_string_literal: true

require 'resque'

module Resque
  module Plugins
    require "#{__dir__}/plugins/status"
  end

  require "#{__dir__}/job_with_status"
end
