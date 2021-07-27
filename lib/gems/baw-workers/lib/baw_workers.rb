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

require_relative '../../baw-app/lib/baw_app'
require_relative '../../baw-audio-tools/lib/baw_audio_tools'

Dir.glob("#{__dir__}/patches/**/*.rb").each do |override|
  #puts "loading #{override}"
  require override
end

require 'zeitwerk'
Zeitwerk::Loader.new.tap do |loader|
  loader.tag = 'baw-workers'
  base_dir = __dir__
  loader.push_dir(base_dir)
  loader.ignore("#{base_dir}/patches")
  loader.inflector.inflect(
    'io' => 'IO'
  )
  #loader.enable_reloading if BawApp.dev_or_test?
  #loader.log! # debug only!
  loader.setup # ready!
end

module BawWorkers
  ROOT = __dir__.to_s
end

# simply mentioning this namespace should allow test-worker to patch jobs
if BawApp.test?

  # Disable the inbuilt test adapter for every test!
  # https://github.com/rails/rails/issues/37270
  (::ActiveJob::Base.descendants << ActiveJob::Base).each do |klass|
    klass.disable_test_adapter if defined?(klass.disable_test_adapter)
  end
  ::ActiveJob::Base.queue_adapter = :resque
end
