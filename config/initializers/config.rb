# A special integration ensures this initializer is called before others in
# the app: https://github.com/rubyconfig/config/blob/master/lib/config/integrations/rails/railtie.rb
# Thus, this file *must* be named `config.rb`!

# Moved this to baw-app so its logic can be reused.
# This should be a noop since BawApp is required in application.rb
require "#{BawApp.root}/lib/gems/baw-app/lib/initializers/config.rb"
