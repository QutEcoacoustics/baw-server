# frozen_string_literal: true

Dir.glob("#{__dir__}/patches/**/*.rb").each do |override|
  #puts "loading #{override}"
  require override
end

require 'zeitwerk'

Zeitwerk::Loader.new.tap do |loader|
  loader.tag = 'pbs'
  base_dir = __dir__
  loader.push_dir(base_dir)
  loader.ignore("#{base_dir}/patches")
  loader.inflector.inflect(
    'pbs' => 'PBS',
    'ssh' => 'SSH'
  )

  loader.enable_reloading if BawApp.dev_or_test?
  #loader.log! # debug only!
  loader.setup # ready!
end

require 'net/ssh'
require 'net/scp'
require 'bcrypt_pbkdf'
require 'ed25519'
require 'semantic_logger'
require 'erb'
require 'stringio'
require 'dry-struct'
require 'dry-transformer'
require 'dry/transformer/conditional'
require 'dry/transformer/recursion'

# module for submitting and enqueuing jobs with a PBS cluster
module PBS
end
