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
require 'baw-workers/common'
require 'baw-workers/mail/mailer'

# set time zone
Time.zone = 'UTC'

module BawWorkers
  autoload :Common, 'baw-workers/common'

  autoload :AudioFileCheck, 'baw-workers/audio_file_check'
  autoload :ApiCommunicator, 'baw-workers/api_communicator'

  module Action
    autoload :MediaAction, 'baw-workers/action/media_action'
    autoload :AudioFileCheckAction, 'baw-workers/action/audio_file_check_action'
  end

  module Mail
    autoload :Mailer, 'baw-workers/mail/mailer'
  end

end
