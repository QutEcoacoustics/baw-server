require 'active_support/all'
require 'logger'
require 'net/http'
require 'pathname'

require 'baw-audio-tools'

require 'resque'
require 'resque_solo'
require 'resque-job-stats'

require 'baw-workers/version'
require 'baw-workers/settings'
require 'baw-workers/register_mime_types'

# set time zone
Time.zone = 'UTC'

module BawWorkers
  autoload :Exceptions, 'baw-workers/exceptions'
  autoload :Common, 'baw-workers/common'
  autoload :ApiCommunicator, 'baw-workers/api_communicator'
  autoload :FileInfo, 'baw-workers/file_info'
  autoload :ResqueApi, 'baw-workers/resque_api'

  module Analysis
    autoload :Action, 'baw-workers/analysis/action'
    autoload :Workhelper, 'baw-workers/analysis/work_helper'
  end

  module AudioCheck
    autoload :Action, 'baw-workers/audio_check/action'
    autoload :WorkHelper, 'baw-workers/audio_check/work_helper'
  end

  module Harvest
    autoload :Action, 'baw-workers/harvest/action'
    autoload :WorkHelper, 'baw-workers/harvest/work_helper'
    autoload :GatherFiles, 'baw-workers/harvest/gather_files'
    autoload :SingleFile, 'baw-workers/harvest/single_file'
  end

  module Mail
    autoload :Mailer, 'baw-workers/mail/mailer'
  end

  module Media
    autoload :Action, 'baw-workers/media/action'
    autoload :WorkHelper, 'baw-workers/media/work_helper'
  end

  module Storage
    autoload :Common, 'baw-workers/storage/common'
    autoload :AnalysisCache, 'baw-workers/storage/analysis_cache'
    autoload :AudioCache, 'baw-workers/storage/audio_cache'
    autoload :AudioOriginal, 'baw-workers/storage/audio_original'
    autoload :DatasetCache, 'baw-workers/storage/dataset_cache'
    autoload :SpectrogramCache, 'baw-workers/storage/spectrogram_cache'
  end

end
