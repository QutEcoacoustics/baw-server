# frozen_string_literal: true

require 'pathname'

module Fixtures
  FIXTURES_PATH = Pathname.new("#{BawApp.root}/spec/fixtures")
  FILES_PATH = FIXTURES_PATH / 'files'

  # @return [Pathname]
  def self.sqlite_fixture
    FILES_PATH / 'example__Tiles.sqlite3'
  end

  # @return [Pathname]
  def self.audio_check_csv
    FILES_PATH / 'audio_check.csv'
  end

  # @return [Pathname]
  def self.audio_file_empty
    FILES_PATH / 'test-audio-empty.ogg'
  end

  # @return [Pathname]
  def self.audio_file_mono
    FILES_PATH / 'test-audio-mono.ogg'
  end

  # @return [Pathname]
  def self.audio_file_mono29
    FILES_PATH / 'test-audio-mono-29.ogg'
  end

  # @return [Pathname]
  def self.audio_file_stereo
    FILES_PATH / 'test-audio-stereo.ogg'
  end

  # @return [Pathname]
  def self.audio_file_wac_1
    FILES_PATH / 'test-wac-1.wac'
  end

  # @return [Pathname]
  def self.audio_file_wac_2
    FILES_PATH / 'test-wac-2.wac'
  end

  # @return [Pathname]
  def self.audio_file_corrupt
    FILES_PATH / 'test-audio-corrupt.ogg'
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
