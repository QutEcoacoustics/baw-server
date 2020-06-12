# frozen_string_literal: true

# resque setup
Resque.redis = ActiveSupport::HashWithIndifferentAccess.new(Settings.resque.connection)
Resque.redis.namespace = Settings.resque.namespace

# logging
# By default, each log is created under Rails.root/log/ and the log file name is <component_name>.<environment_name>.log.

# The default Rails log level is warn in production env and info in any other env.
current_log_level = Logger::DEBUG
current_log_level = Logger::INFO if Rails.env.staging?
current_log_level = Logger::WARN if Rails.env.production?

rails_logger = BawWorkers::MultiLogger.new(Logger.new(Rails.root.join('log', "rails.#{Rails.env}.log")))
rails_logger.attach(Logger.new(STDOUT)) if Rails.env.development?
rails_logger.level = current_log_level

mailer_logger = BawWorkers::MultiLogger.new(Logger.new(Settings.paths.mailer_log_file))
mailer_logger.level = Logger.const_get(Settings.mailer.log_level)

active_record_logger = BawWorkers::MultiLogger.new(Logger.new(Rails.root.join('log', "activerecord.#{Rails.env}.log")))
active_record_logger.attach(Logger.new(STDOUT)) if Rails.env.development?
active_record_logger.level = current_log_level

resque_logger = BawWorkers::MultiLogger.new(Logger.new(Settings.paths.worker_log_file))
resque_logger.level = Logger.const_get(Settings.resque.log_level)

audio_tools_logger = BawWorkers::MultiLogger.new(Logger.new(Settings.paths.audio_tools_log_file))
audio_tools_logger.level = Logger.const_get(Settings.audio_tools.log_level)

# core rails logging
Rails.application.config.logger = rails_logger

# action mailer logging
Rails.application.config.action_mailer.logger = mailer_logger
BawWorkers::Config.logger_mailer = mailer_logger

# activerecord logging
ActiveRecord::Base.logger = active_record_logger

# resque logging
Resque.logger = resque_logger
BawWorkers::Config.logger_worker = resque_logger

# audio tools logging
BawWorkers::Config.logger_audio_tools = audio_tools_logger

# BawWorkers setup
BawWorkers::Config.run_web(rails_logger, mailer_logger, resque_logger, audio_tools_logger, Settings)