# frozen_string_literal: true

require 'pathname'

module Fixtures
  FIXTURES_PATH = Pathname.new("#{BawApp.root}/spec/fixtures")
  FILES_PATH = FIXTURES_PATH / 'files'

  # @return [Pathname]
  def self.sqlite_fixture
    ensure_exists FILES_PATH / 'example__Tiles.sqlite3'
  end

  SQLITE_FIXTURE_FILES = {
    '/BLENDED.Tile_20160727T110000Z_240.png' =>	4393,
    '/BLENDED.Tile_20160727T110000Z_120.png' =>	7989,
    '/BLENDED.Tile_20160727T110000Z_60.png' =>	15_319,
    '/BLENDED.Tile_20160727T123000Z_30.png' =>	29_977,
    '/BLENDED.Tile_20160727T123000Z_15.png' =>	60_483,
    '/sub_dir_2/BLENDED.Tile_20160727T123000Z_7.5.png' =>	92_507,
    '/sub_dir_2/BLENDED.Tile_20160727T125230Z_7.5.png' =>	33_554,
    '/sub_dir_1/BLENDED.Tile_20160727T122624Z_3.2.png' =>	65_360,
    '/sub_dir_1/BLENDED.Tile_20160727T123600Z_3.2.png' =>	97_722,
    '/sub_dir_1/BLENDED.Tile_20160727T124536Z_3.2.png' =>	100_993
  }.freeze

  # @return [Pathname]
  def self.zip_fixture
    ensure_exists FILES_PATH / 'compressed.zip'
  end

  # @return [Pathname]
  def self.audio_check_csv
    ensure_exists FILES_PATH / 'audio_check.csv'
  end

  # @return [Pathname]
  def self.hoot_detective
    ensure_exists FILES_PATH / 'Hoot Detective data 12 october 2021-cleaned.csv'
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

  # @return [Pathname]
  def self.bowra2_image_jpeg
    ensure_exists FILES_PATH / 'IMG_night.jpg'
  end

  # @return [Pathname]
  def self.a_very_large_image_jpeg
    ensure_exists FILES_PATH / 'a_very_large_image.jpg'
  end

  def self.bar_lt_faulty_duration
    ensure_exists FILES_PATH / '3.17_Duration' / '20200801T000000+1000_REC.flac'
  end

  def self.bar_lt_preallocated_header
    ensure_exists FILES_PATH / '3.14_PreallocatedHeader' / '20191125_AAO' / '20191125T000000+1000_REC.flac'
  end

  # rubocop:disable Naming/MethodName
  def self.problem_WA002
    ensure_exists FILES_PATH / 'WA_SM3_1.35A' / 'SM304290_0+1_20211001_130001.wav'
  end

  def self.partial_file_FL011
    ensure_exists FILES_PATH / '3.17_PartialDataFiles' / 'Robson-Creek-Dry-A_201' / '20200426_STUDY' / 'data'
  end

  def self.partial_file_FL011_empty
    ensure_exists FILES_PATH / '3.17_PartialDataFiles' / 'Robson-Creek-Dry-A_201' / '20210416_STUDY' / 'data'
  end
  # rubocop:enable Naming/MethodName

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
