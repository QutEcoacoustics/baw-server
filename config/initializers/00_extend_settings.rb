require_relative '../settings.rb'

# patch the rubyconfig/config settings object with our custom class
module Config
  class Options
    prepend BawWeb::Settings
  end
end


