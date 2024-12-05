# frozen_string_literal: true

# Add new mime types:
# Mime::Type.register "text/richtext", :rtf
# Mime::Type.register_alias "text/html", :iphone

require 'action_dispatch/http/mime_type'

# audio mime types
Mime::Type.register 'audio/wav', :wav, ['audio/x-wav', 'audio/vnd.wave', 'audio/L16'], ['wave']
Mime::Type.register 'audio/mpeg', :mp3, ['audio/mp3'], ['mp1', 'mp2', 'mp3', 'mpg', 'mpeg', 'mpeg3']
Mime::Type.register 'audio/webm', :webm, ['audio/webma'], ['webma']
Mime::Type.register 'audio/ogg', :ogg, ['audio/oga'], ['oga']
Mime::Type.register 'audio/asf', :asf, ['audio/x-ms-asf', 'audio/x-ms-wma', 'audio/wma', 'video/x-ms-asf'], ['wma']
Mime::Type.register 'audio/wavpack', :wv, ['audio/wv', 'audio/x-wv', 'audio/x-wavpack'], ['wavpack']
Mime::Type.register 'audio/aac', :aac, [], []
Mime::Type.register 'audio/mp4', :mp4, ['audio/m4a'], ['mov', 'm4a', '3gp', '3g2', 'mj2']
Mime::Type.register 'audio/x-flac', :flac, ['audio/flac'], []
Mime::Type.register 'audio/x-waac', :wac, ['audio/waac', 'audio/wac', 'audio/x-wac'], []

# text mime types
Mime::Type.register 'application/x-yaml', :yml, [
  'text/yaml',
  'text/x-yaml',
  'application/yaml',
  'text/yml',
  'text/x-yml',
  'application/yml',
  'application/x-yml'
], ['yaml']
Mime::Type.register 'text/plain', :log, [], []

# other
Mime::Type.register 'application/x-sqlite3', :sqlite3, [], []
Mime::Type.register 'image/png', :png, [], []
