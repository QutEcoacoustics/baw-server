require 'active_support/all'
require 'logger'
require 'baw-audio-tools'
require 'resque'
require 'resque_solo'

require 'baw-workers/version'
require 'baw-workers/settings'

# set time zone
Time.zone = 'UTC'

module BawWorkers
  autoload :MediaAction, 'baw-workers/media_action'
end
