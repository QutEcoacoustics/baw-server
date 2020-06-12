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
require 'resque-status'

require_relative '../../baw-app/lib/baw_app.rb'
require_relative '../../baw-audio-tools/lib/baw_audio_tools.rb'

Dir.glob("#{__dir__}/patches/**/*.rb").sort.each do |override|
  #puts "loading #{override}"
  require override
end

require 'zeitwerk'
Zeitwerk::Loader.new.tap do |loader|
  loader.tag = 'baw-workers'
  base_dir = __dir__
  loader.push_dir(base_dir)
  loader.ignore("#{base_dir}/patches")
  loader.enable_reloading if BawApp.development?
  #loader.log! # debug only!
  loader.setup # ready!
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
