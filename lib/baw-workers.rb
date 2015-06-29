require 'active_support/all'
require 'logger'
require 'net/http'
require 'pathname'
require 'yaml'
require 'fileutils'

require 'baw-audio-tools'

require 'resque'
require 'resque_solo'
require 'resque-job-stats'
require 'resque-status'

require 'baw-workers/version'
require 'baw-workers/register_mime_types'
require 'baw-workers/settings'

# set time zone
Time.zone = 'UTC'

# Bioacoustics Workbench workers.
# Workers that can process various long-running or intensive tasks.
module BawWorkers
  autoload :MultiLogger, 'baw-workers/multi_logger'
  autoload :Config, 'baw-workers/config'
  autoload :Exceptions, 'baw-workers/exceptions'
  autoload :Validation, 'baw-workers/validation'
  autoload :ActionBase, 'baw-workers/action_base'
  autoload :ApiCommunicator, 'baw-workers/api_communicator'
  autoload :FileInfo, 'baw-workers/file_info'
  autoload :ResqueApi, 'baw-workers/resque_api'
  autoload :ResqueJobId, 'baw-workers/resque_job_id'

  module Analysis
    autoload :Action, 'baw-workers/analysis/action'
    autoload :Payload, 'baw-workers/analysis/payload'
    autoload :Runner, 'baw-workers/analysis/runner'
  end

  module AudioCheck
    autoload :Action, 'baw-workers/audio_check/action'
    autoload :WorkHelper, 'baw-workers/audio_check/work_helper'
    autoload :CsvHelper, 'baw-workers/audio_check/csv_helper'
  end

  module Harvest
    autoload :Action, 'baw-workers/harvest/action'
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

  module Mirror
    autoload :Action, 'baw-workers/mirror/action'
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
