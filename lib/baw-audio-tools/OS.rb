# Helper for detecting current operating system.
# @see http://stackoverflow.com/questions/170956/how-can-i-find-which-operating-system-my-ruby-program-is-running-on
module OS

  # Running on Windows?
  def OS.windows?
    (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end

  # Running on a mac?
  def OS.mac?
   (/darwin/ =~ RUBY_PLATFORM) != nil
  end

  # Running on unix?
  def OS.unix?
    !OS.windows?
  end

  # Running on linux?
  def OS.linux?
    OS.unix? && !OS.mac?
  end
end