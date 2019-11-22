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

require 'zeitwerk'
loader = Zeitwerk::Loader.new
loader.push_dir(__dir__)
loader.ignore("#{__dir__}/tasks")
loader.tag = 'baw-workers'
loader.inflector.inflect(
  'baw-workers' => 'BawWorkers',
  'baw-audio-tools' => 'BawAudioTools'
)
loader.enable_reloading
#loader.log! # debug only!
loader.setup # ready!

# set time zone
Time.zone = 'UTC'

# Acoustic Workbench workers.
# Workers that can process various long-running or intensive tasks.
# Note: all sub-modules in folder baw-workers are loaded on demand thanks to
#   zeitwerk
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
