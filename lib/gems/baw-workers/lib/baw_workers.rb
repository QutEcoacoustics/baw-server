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
require "#{__dir__}/../../resque-status/lib/resque-status"
unless defined?(Resque::Plugins::Status::EXPIRE_STATUSES)
  raise 'sanity check failed: modified resque status hash class not loaded'
end

require 'active_job'
# Note: this defines the Rails constant which causes issues. See tasks/run_worker.rake

require 'active_storage'
require 'active_storage/engine'

require_relative '../../baw-app/lib/baw_app'
require_relative '../../baw-audio-tools/lib/baw_audio_tools'

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
  #loader.enable_reloading if BawApp.dev_or_test?
  #loader.log! # debug only!
  loader.setup # ready!
end

module BawWorkers
  MODULE_ROOT = __dir__.to_s

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

  module UploadService
  end
end

# simply mentioning this namespace should allow test-worker to patch jobs
if BawApp.test?
  raise 'Resque::Job has not been patched for tests' unless Resque::Job.include?(Resque::Plugins::PauseDequeueForTests)
end
