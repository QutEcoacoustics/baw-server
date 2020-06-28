# frozen_string_literal: true

require 'dry-validation'
require 'config'

Dir.glob("#{__dir__}/patches/**/*.rb").sort.each do |override|
  require override
end

Dir.glob("#{__dir__}/initializers/**/*.rb").sort.each do |file|
  require file
end

# A module for app wide constants or defs.
module BawApp
  # makes module methods 'static'

  module_function

  def root
    @root ||= Pathname.new("#{__dir__}/../../../..").cleanpath
  end

  def config_root
    @config_root ||= root / 'config'
  end

  def env
    return Rails.env if defined?(Rails) && defined?(Rails.env)

    # https://github.com/rails/rails/blob/1ccc407e9dc95bda4d404c192bbb9ce2b8bb7424/railties/lib/rails.rb#L67
    @env ||= ActiveSupport::StringInquirer.new(
      ENV['RAILS_ENV'].presence || ENV['RACK_ENV'].presence || 'development'
    )
  end

  # Get the path to the default config files that will be loaded by the app
  def config_files(config_root = self.config_root, env = self.env)
    [
      File.join(config_root, 'settings.yml').to_s,
      File.join(config_root, 'settings', 'default.yml').to_s,
      File.join(config_root, 'settings', "#{env}.yml").to_s
    ].freeze
  end

  def development?
    env == 'development'
  end

  def test?
    ENV['RUNNING_RSPEC'] == 'yes' || env == 'test'
  end

  # currently a no-op, thinking about collapsing the concept of initializers and patches
  def initialize; end
end
