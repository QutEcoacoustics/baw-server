# included in rails_helpers.rb
module ApiSpecHelpers
  def result
    JSON.parse(response.body)
  end
end
