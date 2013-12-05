module Logging
  # This is the magical bit that gets mixed into your classes
  def logger
    Logging.logger
  end

  # Global, memoized, lazy initialized instance of a logger
  def self.logger

    @logger ||= Logger.new(Settings.paths.modules_log_file, 5, 300.megabytes)
  end

  def self.set_logger(new_logger)
    @logger = new_logger
  end

  #def module_exists?(name, base = self.class)
  #  base.const_defined?(name) && base.const_get(name).instance_of?(::Module)
  #end
end