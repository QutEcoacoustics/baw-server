# frozen_string_literal: true

require 'pathname'

module Fixtures
  FIXTURES_PATH = Pathname.new("#{::Rails.root}/spec/fixtures")
  FILES_PATH = FIXTURES_PATH / 'files'

  # @return [Pathname]
  def self.sqlite_fixture
    FILES_PATH / 'example__Tiles.sqlite3'
  end

  # @return [Pathname]
  def self.audio_file_mono
    FILES_PATH / 'test-audio-mono.ogg'
  end

  # @return [Pathname]
  def self.audio_file_mono_long
    FILES_PATH / 'test-audio-mono-long.ogg'
  end

  # @return [Pathname]
  def self.audio_file_stereo_7777hz
    FILES_PATH / 'test-audio-stereo-7777hz.ogg'
  end
end
