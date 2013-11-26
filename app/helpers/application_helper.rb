module ApplicationHelper

  def sidebar_metadata(title, text)
    unless title.blank? || text.blank?
      content_tag(:div, class: 'metadata') do
        content_tag(:div, title, class: 'heading') +
        content_tag(:div, text, class: 'text')
      end
    end
    end
  def sidebar_metadata_users(title, users)
    unless title.blank? || users[0][:user].blank?
      content_tag(:div, class: 'metadata') do
        content_tag(:div, title, class: 'heading') +
        content_tag(:ul, class: 'thumbnails') do
          users.collect!{ |user| render partial: 'user_accounts/user_thumbnail_small', locals: {user: user[:user], subtext: user[:subtext]}}.join.html_safe
        end
      end
    end
  end

  def gmaps_default_options
    { zoom: 7, auto_zoom: false}
  end
end
