module BawAudioTools
  module Logging
    # This is the magical bit that gets mixed into your classes
    def logger
      BawAudioTools::Logging.logger
    end

    # Global, memoized, lazy initialized instance of a logger
    def self.logger
      # requires Settings 'Settings.paths.modules_log_file' value to be available
      @logger ||= Logger.new(Settings.paths.modules_log_file)
      self.logger_formatter(@logger)
      set_level
      @logger
    end

    def self.set_logger(new_logger)
      @logger = new_logger
      self.logger_formatter(@logger)
      set_level
      @logger
    end

    def self.set_formatter(formatter = Logger::Formatter.new)
      @logger.formatter = formatter
    end

    def self.set_level(level = Logger::INFO)
      @logger.level = level
    end

    def self.logger_formatter(logger)
      logger.formatter = BawAudioTools::CustomFormatter.new
    end
  end
end