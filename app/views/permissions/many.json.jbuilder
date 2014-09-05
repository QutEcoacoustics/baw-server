json.array! @permissions do |permission|
  json.(permission, *Permission.filter_settings.render_fields)
end