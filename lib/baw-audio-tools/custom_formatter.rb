module BawAudioTools
  class CustomFormatter < Logger::Formatter
    def call(severity, datetime, progname, msg)
      time = datetime.strftime('%Y-%m-%dT%H:%M:%S.') << '%03d' % datetime.usec.to_s[0..2].rjust(3)
      sev = '%5s' % severity
      pid = '%06d' % $$
      # e.g. 2014-04-07T09:49:13.290+0000 [ WARN--024611] <msg>
      # msg2str is the internal helper that handles strings and exceptions correctly
      "#{time}#{datetime.strftime('%z')} [#{sev}-#{progname}-#{pid}] #{msg2str(msg)}\n"
    end
  end
end