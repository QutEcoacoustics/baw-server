require 'net/http'
require 'json'
require 'pathname'
require 'logger'

module Helpers
  include Exceptions, Logging

  def construct_json_post(endpoint, body)
    post_request = Net::HTTP::Post.new(endpoint)
    post_request["Content-Type"] = "application/json"
    post_request["Accept"] = "application/json"
    post_request.body = body.to_json
    post_request
  end

  def construct_login_request(email, password, endpoint)
    # set up the login HTTP post
    content = {:user => {:email => email, :password => password}}
    construct_json_post(endpoint, content)
  end

  # TODO: delete?
  #def make_absolute(base_dir, path)
  #  Pathname.new(path).absolute? ? path : File.join(base_dir, path)
  #end
end