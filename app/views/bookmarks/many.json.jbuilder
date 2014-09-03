json.array! @bookmarks do |bookmark|
  json.(bookmark, *Bookmark.filter_settings.render_fields)
end