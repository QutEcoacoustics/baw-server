json.set! :meta do

  if !@view_info.blank? && !@view_info.status_code.blank?
    json.set! :status, @view_info.status_code
  else
    json.set! :status, 200
  end

  if !@view_info.blank? && !@view_info.status_message.blank?
    json.set! :message, @view_info.status_message
  else
    json.set! :message, 'OK'
  end
end

json.data JSON.parse(yield)
#
# if @view_info.data.is_a?(Array)
#   #json.array! @view_info.data, partial: @view_info.partial_view, as: @view_info.view_container
# else
#   #json.partial! @view_info.data, partial: @view_info.partial_view, as: @view_info.view_container
# end