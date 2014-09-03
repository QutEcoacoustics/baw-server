json.array! @audio_event_comments do |audio_event_comment|
  json.(audio_event_comment, *AudioEventComment.filter_settings.render_fields)
end