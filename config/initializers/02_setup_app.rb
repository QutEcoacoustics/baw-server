# frozen_string_literal: true
Rails.application.reloader.to_prepare do
  BawWorkers::Config.run_web(Rails.logger, Settings)
end
