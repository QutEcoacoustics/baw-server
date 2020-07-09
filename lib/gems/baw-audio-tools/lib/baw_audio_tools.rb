# frozen_string_literal: true

require_relative '../../baw-app/lib/baw_app.rb'

require 'zeitwerk'
Zeitwerk::Loader.new.tap do |loader|
  loader.tag = 'baw-audio-tools'
  base_dir = __dir__
  loader.push_dir(base_dir)
  loader.enable_reloading if BawApp.development?
  #loader.log! # debug only!
  loader.setup # ready!
end

module BawAudioTools
end
