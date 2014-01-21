require 'active_support/buffered_logger'

module Logging
  # This is the magical bit that gets mixed into your classes
  def logger
    Logging.logger
  end

  # Global, memoized, lazy initialized instance of a logger
  def self.logger
    # requires 'environment' to be loaded so Settings are available
    @logger ||= Logger.new(Settings.paths.modules_log_file, 5, 20.megabytes)
    set_formatter
    set_level
    @logger
  end

  def self.set_logger(new_logger)
    @logger = new_logger
    set_formatter
    set_level
    @logger
  end

  #def module_exists?(name, base = self.class)
  #  base.const_defined?(name) && base.const_get(name).instance_of?(::Module)
  #end

  private

  def self.set_formatter
    @logger.formatter = Logger::Formatter.new
  end

  def self.set_level
    @logger.level = Logger::INFO
  end
end