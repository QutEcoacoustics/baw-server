# frozen_string_literal: true

module BawWorkers
  # Multilogger is a subclass of the standard Ruby logger that does not itself write
  # messages anywhere. Rather, it serves as a wrapper around multiple Logger-compatible
  # destinations.
  # @see https://github.com/ffmike/multilogger/blob/master/multi_logger.rb source document
  # @see http://stackoverflow.com/a/18118055
  class MultiLogger < Logger
    # Array of Loggers to be logged to. These can be anything that acts reasonably like a Logger.
    attr_accessor :loggers

    #
    # === Synopsis
    #
    #   MultiLogger.new([logger1, logger2])
    #
    # === Args
    #
    # +loggers+::
    #   An array of loggers. Each one gets every message that is sent to the MultiLogger instance
    #
    # === Description
    #
    # Create an instance.
    #
    def initialize(*loggers)
      @loggers = []
      loggers.each do |logger|
        attach(logger)
      end
    end

    # Attach a logger to this multi logger.
    def attach(logger)
      raise ArgumentError, "Must be a Logger, given #{logger.inspect}." unless logger.is_a?(::Logger)

      logger.formatter = CustomFormatter.new if logger.respond_to?(:formatter=)
      @loggers.push(logger)
    end

    # Methods that write to logs just write to each contained logger in turn
    def add(severity, message = nil, progname = nil, &block)
      @loggers.each do |logger|
        logger.add(severity, message, progname, &block) if logger.respond_to?(:add)
      end
    end
    alias log add

    def <<(msg)
      @loggers.each do |logger|
        logger << msg if logger.respond_to?(:<<)
      end
    end

    def debug(progname = nil, &block)
      @loggers.each do |logger|
        logger.debug(progname, &block) if logger.respond_to?(:debug)
      end
    end

    def info(progname = nil, &block)
      @loggers.each do |logger|
        logger.info(progname, &block) if logger.respond_to?(:info)
      end
    end

    def warn(progname = nil, &block)
      @loggers.each do |logger|
        logger.warn(progname, &block) if logger.respond_to?(:warn)
      end
    end

    def error(progname = nil, &block)
      @loggers.each do |logger|
        logger.error(progname, &block) if logger.respond_to?(:error)
      end
    end

    def fatal(progname = nil, &block)
      @loggers.each do |logger|
        logger.fatal(progname, &block) if logger.respond_to?(:fatal)
      end
    end

    def unknown(progname = nil, &block)
      @loggers.each do |logger|
        logger.unknown(progname, &block) if logger.respond_to?(:unknown)
      end
    end

    def close
      @loggers.each do |logger|
        # Why can't this just call logger.close ?
        logger.instance_eval('@logdev')&.close
      end
    end

    # Returns +true+ iff the current severity level of at least one logger
    # allows for the printing of +DEBUG+ messages.
    def debug?
      @loggers.any? { |logger| logger.respond_to?(:debug?) && logger.debug? }
    end

    # Returns +true+ iff the current severity level of at least one logger
    # allows for the printing of +INFO+ messages.
    def info?
      @loggers.any? { |logger| logger.respond_to?(:info?) && logger.info? }
    end

    # Returns +true+ iff the current severity level of at least one logger
    # allows for the printing of +WARN+ messages.
    def warn?
      @loggers.any? { |logger| logger.respond_to?(:warn?) && logger.warn? }
    end

    # Returns +true+ iff the current severity level of at least one logger
    # allows for the printing of +ERROR+ messages.
    def error?
      @loggers.any? { |logger| logger.respond_to?(:error?) && logger.error? }
    end

    # Returns +true+ iff the current severity level of at least one logger
    # allows for the printing of +FATAL+ messages.
    def fatal?
      @loggers.any? { |logger| logger.respond_to?(:fatal?) && logger.fatal? }
    end

    # Logging severity threshold (e.g. <tt>Logger::INFO</tt>).
    # Retrieve from the first logger.
    # Assumed that this will be the same across all contained loggers.
    def level
      @loggers.each do |logger|
        return logger.level if logger.respond_to?(:level)
      end
    end

    # Set level on all contained loggers.
    def level=(value)
      @loggers.each do |logger|
        logger.level = value if logger.respond_to?(:level=)
      end
    end

    # Program name to include in log messages.
    # Retrieve from the first logger.
    # Assumed that this will be the same across all contained loggers.
    def progname
      @loggers.each do |logger|
        return logger.progname if logger.respond_to?(:progname)
      end
    end

    # Set progname on all contained loggers.
    def progname=(value)
      @loggers.each do |logger|
        logger.progname = value if logger.respond_to?(:progname=)
      end
    end

    # Formatter for displaying log messages.
    # Retrieve from the first logger.
    # Assumed that this will be the same across all contained loggers.
    def formatter
      @loggers.each do |logger|
        return logger.formatter if logger.respond_to?(:formatter)
      end
    end

    # Set formatter on all contained loggers.
    def formatter=(value)
      @loggers.each do |logger|
        logger.formatter = value if logger.respond_to?(:formatter=)
      end
    end

    # Returns the date format being used.  See #datetime_format=
    # Retrieve from the first logger.
    # Assumed that this will be the same across all contained loggers.
    def datetime_format
      @loggers.each do |logger|
        return logger.datetime_format if logger.respond_to?(:datetime_format)
      end
    end

    # Set date-time format on all contained loggers.
    # +datetime_format+:: A string suitable for passing to +strftime+.
    def datetime_format=(datetime_format)
      @loggers.each do |logger|
        logger.datetime_format = datetime_format if logger.respond_to?(:datetime_format=)
      end
    end

    # Any method not defined on standard Logger class, just send it on to anyone who will listen
    def method_missing(name, *args, &block)
      @loggers.each do |logger|
        logger.send(name, args, &block) if logger.respond_to?(name)
      end
    end

    # Write method helps this class look like an IO class.
    # Anything recorded here is logged as info.
    def write(message = nil)
      info('MultiLogger#write') { message }
    end

    # Default formatter for log messages.
    class CustomFormatter < Logger::Formatter
      def call(severity, time, progname, msg)
        sev = format('%5s', severity)
        pid = $PROCESS_ID.nil? ? '?' : format('%06d', $PROCESS_ID)
        # e.g. 2014-04-07T09:49:13.290+0000 [ WARN--024611] <msg>
        # msg2str is the internal helper that handles strings and exceptions correctly
        "#{format_datetime(time)}#{time.strftime('%z')} [#{sev}-#{progname}-#{pid}] #{msg2str(msg)}\n"
      end

      private

      def format_datetime(time)
        if @datetime_format.nil?
          #time.strftime("%Y-%m-%dT%H:%M:%S.") << "%06d " % time.usec
          time.strftime('%Y-%m-%dT%H:%M:%S.') << format('%03d', time.usec.to_s[0..2].rjust(3))
        else
          time.strftime(@datetime_format)
        end
      end
    end
  end
end
