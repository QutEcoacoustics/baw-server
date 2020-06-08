# frozen_string_literal: true

require 'active_support/all'
require 'logger'
require 'net/http'
require 'pathname'
require 'yaml'
require 'fileutils'
require 'resque'
require 'resque_solo'
require 'resque-job-stats'

Dir.glob("#{__dir__}/baw_workers/patches/**/*.rb").sort.each do |override|
  #puts "loading #{override}"
  require override
end

module BawWorkers
  module Analysis
  end

  module AudioCheck
  end

  module Harvest
  end

  module Mail
  end

  module Media
  end

  module Mirror
  end

  module Storage
  end

  module Template
  end
end
