# Be sure to restart your server when you modify this file.

#ActiveSupport::Reloader.to_prepare prepend: true do
  # ApplicationController.renderer.defaults.merge!(
  #   http_host: 'example.org',
  #   https: false
  # )
#end

ActiveSupport::Reloader.before_class_unload do
  Rails.logger.warn '\nReload triggered!'
end
