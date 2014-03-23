require 'active_support/all'
require 'logger'
require 'baw-audio-tools'

require 'baw-workers/version'

module BawWorkers
  autoload :PullWorker, 'baw-workers/pull_worker'
  autoload :PushWorker, 'baw-workers/push_worker'
  autoload :SpectrogramRequestWorker, 'baw-workers/spectrogram_request_worker'
  autoload :AudioRequestWorker, 'baw-workers/audio_request_worker'
  autoload :MediaRequestWorker, 'baw-workers/media_request_worker'
  autoload :EagerCacheWorker, 'baw-workers/eager_cache_worker'
end
