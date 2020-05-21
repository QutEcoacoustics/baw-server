# frozen_string_literal: true

# A module for app wide constants or defs.
module BawApp
  # makes module methods 'static'

  module_function

  def root
    @root ||= Pathname.new("#{__dir__}/../..").cleanpath
  end

  def env
    return Rails.env if defined?(Rails)

    # https://github.com/rails/rails/blob/1ccc407e9dc95bda4d404c192bbb9ce2b8bb7424/railties/lib/rails.rb#L67
    @env ||= ActiveSupport::StringInquirer.new(
      ENV['RAILS_ENV'].presence || ENV['RACK_ENV'].presence || 'development'
    )
  end

  def development?
    env == 'development'
  end

  def test?
    ENV['RUNNING_RSPEC'] == 'yes' || env == 'test'
  end

  def initialize
    require_relative('baw_app/initializers/register_mime_types')
  end
end
