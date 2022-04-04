# frozen_string_literal: true

require_relative '../settings'

# patch the rubyconfig/config settings object with our custom class
module Config
  class Options
    prepend BawWeb::Settings
  end
end
