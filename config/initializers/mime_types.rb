# Be sure to restart your server when you modify this file.

# Add new mime types for use in respond_to blocks:
# Mime::Type.register "text/richtext", :rtf
# Mime::Type.register_alias "text/html", :iphone

# audio mime types
Mime::Type.register 'audio/wav', :wav, ['audio/x-wav', 'audio/vnd.wave', 'audio/L16'], ['wave']
Mime::Type.register 'audio/mp3', :mp3, ['audio/mpeg'], ['mp1', 'mp2', 'mp3', 'mpg','mpeg','mpeg3']
Mime::Type.register 'audio/webm', :webm, ['audio/webma'], ['webma']
Mime::Type.register 'audio/ogg', :ogg, ['audio/oga'], ['oga']
Mime::Type.register 'audio/asf', :asf, ['audio/x-ms-asf', 'audio/x-ms-wma', 'audio/wma','video/x-ms-asf'], ['wma']
Mime::Type.register 'audio/wavpack', :wv, ['audio/wv', 'audio/x-wv', 'audio/x-wavpack'], ['wavpack']
Mime::Type.register 'audio/aac', :aac, [], []
Mime::Type.register 'audio/mp4', :mp4, ['audio/m4a'], ['mov','m4a','3gp','3g2','mj2']
Mime::Type.register 'audio/x-flac', :flac, ['audio/flac'], []

# text mime types
Mime::Type.register 'application/x-yaml', :yml, ['text/yaml', 'text/x-yaml','application/yaml','text/yml', 'text/x-yml','application/yml','application/x-yml'], ['yaml']

