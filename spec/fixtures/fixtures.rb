# frozen_string_literal: true

require 'pathname'

module Fixtures
  FIXTURES_PATH = Pathname.new("#{BawApp.root}/spec/fixtures")
  FILES_PATH = FIXTURES_PATH / 'files'

  # @return [Pathname]
  def self.sqlite_fixture
    ensure_exists FILES_PATH / 'example__Tiles.sqlite3'
  end

  # @return [Pathname]
  def self.audio_check_csv
    ensure_exists FILES_PATH / 'audio_check.csv'
  end

  # @return [Pathname]
  def self.audio_file_empty
    ensure_exists FILES_PATH / 'test-audio-empty.ogg'
  end

  # @return [Pathname]
  def self.audio_file_mono
    ensure_exists FILES_PATH / 'test-audio-mono.ogg'
  end

  # @return [Pathname]
  def self.audio_file_mono29
    ensure_exists FILES_PATH / 'test-audio-mono-29.ogg'
  end

  # @return [Pathname]
  def self.audio_file_stereo
    ensure_exists FILES_PATH / 'test-audio-stereo.ogg'
  end

  # @return [Pathname]
  def self.audio_file_wac_1
    ensure_exists FILES_PATH / 'test-wac-1.wac'
  end

  # @return [Pathname]
  def self.audio_file_wac_2
    ensure_exists FILES_PATH / 'test-wac-2.wac'
  end

  # @return [Pathname]
  def self.audio_file_corrupt
    ensure_exists FILES_PATH / 'test-audio-corrupt.ogg'
  end

  # @return [Pathname]
  def self.audio_file_mono_long
    ensure_exists FILES_PATH / 'test-audio-mono-long.ogg'
  end

  # @return [Pathname]
  def self.audio_file_stereo_7777hz
    ensure_exists FILES_PATH / 'test-audio-stereo-7777hz.ogg'
  end

  # @return [Pathname]
  def self.audio_file_amp_channels_1
    ensure_exists FILES_PATH / 'amp-channels-1.flac'
  end

  # @return [Pathname]
  def self.audio_file_amp_channels_2
    ensure_exists FILES_PATH / 'amp-channels-2.flac'
  end

  # @return [Pathname]
  def self.audio_file_amp_channels_3
    ensure_exists FILES_PATH / 'amp-channels-3.flac'
  end

  # @return [Pathname]
  def self.bar_lt_file
    ensure_exists FILES_PATH / '70' / '0515' / '20190913T000000+1000_REC.flac'
  end

  # @return [Pathname]
  def self.bowra_image_jpeg
    ensure_exists FILES_PATH / 'IMG_1318.JPG'
  end

  #
  # Check a fixture exists
  #
  # @param [Pathname] pathname The path to check
  #
  # @return [Pathname] The path checked
  #
  def self.ensure_exists(pathname)
    unless pathname.exist?
      raise IOError,
            "Given fixture refers to a file that does not exist: #{pathname}"
    end

    pathname
  end
end
