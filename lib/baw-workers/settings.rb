require 'settingslogic'

in_rails = false
begin
  klass = Module.const_get('Rails')
  in_rails = klass.is_a?(Class)
rescue NameError
  in_rails = false
end

if !in_rails && ENV['RAILS_ENV'] != 'test' && !ENV['baw-workers-env'] != 'test'
  class Settings < Settingslogic
    source File.join(File.dirname(__FILE__), 'settings', 'settings.dev.yml')
    namespace 'settings'
  end
end