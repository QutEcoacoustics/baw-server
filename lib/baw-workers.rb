require 'active_support/all'
require 'logger'
require 'baw-audio-tools'
require 'resque'
require 'resque_solo'

require 'baw-workers/version'
require 'baw-workers/settings'

module BawWorkers
  autoload :MediaAction, 'baw-workers/media_action'
end
