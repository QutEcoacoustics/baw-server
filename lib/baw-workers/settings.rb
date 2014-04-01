require 'settingslogic'

if ENV.include?('BAW_WORKERS_ENV') && ENV['BAW_WORKERS_ENV'] == 'RAKEFILE'
  class Settings < Settingslogic
    namespace 'settings'
  end
end