# frozen_string_literal: true

require 'active_support/all'
require 'logger'
require 'net/http'
require 'pathname'
require 'yaml'
require 'fileutils'
require 'resque'
require 'resque/server'
require 'resque-job-stats'

require 'active_job'
require 'active_storage'
require 'active_storage/engine'

require 'action_mailer'
require 'zeitwerk'

require_relative '../../baw-app/lib/baw_app'
require_relative '../../pbs/lib/pbs'

Dir.glob("#{__dir__}/patches/**/*.rb").each do |override|
  #puts "loading #{override}"
  require override
end

BAW_WORKERS_AUTOLOADER = Zeitwerk::Loader.new.tap do |loader|
  loader.tag = 'baw-workers'
  base_dir = __dir__
  loader.push_dir(base_dir)
  loader.ignore("#{base_dir}/patches")
  loader.ignore("#{base_dir}/**/_*.rb")
  loader.inflector.inflect(
    'io' => 'IO'
  )
  #loader.enable_reloading if BawApp.dev_or_test?
  #loader.log! # debug only!
  loader.setup # ready!
end

# Module for background workers.
module BawWorkers
  ROOT = __dir__.to_s
end
