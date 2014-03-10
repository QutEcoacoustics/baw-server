require 'spec_helper'
require 'modules/exceptions'
require 'external/harvester/harvest_file'

require 'fakefs/spec_helpers'

describe Harvester::File do
  context 'recorded date parsing' do
    include FakeFS::SpecHelpers

    before(:each) do
      @harvest_shared = Object
      @harvest_shared.should_receive(:log_with_puts).once

    end

    it 'should error if the file does not exist' do
      file_name = 'blah.ext'
      harvest_file = Harvester::File.new(file_name, @harvest_shared)
      expect {
        harvest_file.get_file_info_from_name('+03')
      }.to raise_error(Exceptions::HarvesterError, /Could not find audio file/)
    end

    it 'should parse a regular date and time file name correctly' do
      file_name = 'site_name_20140301_085031.mp3'
      FileUtils.touch(file_name)
      harvest_file = Harvester::File.new(file_name, @harvest_shared)
      result = harvest_file.get_file_info_from_name('+11')

      expect(result[:recording_start]).to eq(DateTime.new(2014, 3, 1, 8, 50, 31, '+11'))
      expect(result[:file_name]).to eq(file_name)
      expect(result[:prefix]).to eq('site_name')
      expect(result[:extension]).to eq('mp3')
    end

    it 'should parse a file without a matching file name correctly' do
      file_name = 'my_audio_file.mp3'
      FileUtils.touch(file_name)
      file_mtime = File.mtime(file_name)
      harvest_file = Harvester::File.new(file_name, @harvest_shared)
      result = harvest_file.get_file_info_from_name('+0')

      expect(result[:recording_start]).to eq(file_mtime)
      expect(result[:file_name]).to eq(file_name)
      expect(result[:extension]).to eq('mp3')
    end

    it 'should parse a regular ALL THE INFO! file name correctly' do
      file_name = 'p143_s254_u1045_d20140228_t235959Z.wav'
      harvest_file = Harvester::File.new(file_name, @harvest_shared)
      FileUtils.touch(file_name)
      result = harvest_file.get_file_info_from_name

      expect(result[:recording_start]).to eq(DateTime.new(2014, 2, 28, 23, 59, 59, '+0'))
      expect(result[:file_name]).to eq(file_name)
      expect(result[:project_id]).to eq(143)
      expect(result[:site_id]).to eq(254)
      expect(result[:uploader_id]).to eq(1045)
      expect(result[:extension]).to eq('wav')
    end
  end
=begin
For: Harvester::File.get_file_info_from_name
All Incorrect
-------------
blah
blah.ext
.ext.ext.ext
hi.hi
yyyymmdd_hhmmss.ext
_yyyymmdd_hhmmss.ext
blah_yyyymmdd_hhmmss.ext_blah
blah_yyyymmdd_hhmmss.ext_blah
blah_yyyymmdd_hhmmss.ext.blah
yyyymmdd_hhmmss_yyyymmdd_hhmmss.ext.blah
yyyymmdd_hhmmssyyyymmdd_hhmmss.ext.blah
yyyymmdd_hhmmssyyyymmdd_hhmmss.ext

20140301_205031.ext
_20140301_205031.ext
prefix_20140301_085031_postfix.ext
0140301_205031.ext
20140301205031.ext
20140301_205031_ext
prefix_2014001_085031_postfix.ext

p1_s1_u1_d20140301_t000000.ext
1_s1_u1_d20140301_t000000.ext
p1_s1_1_d20140301_t000000.ext
p1_s1_u1_d0140301_t000000.ext
p1_s1_u1_d20140301_t00000Z.ext

All Correct
--------------
a_20140301_205031.ext
sdncv*&^%34jd_20140301_085031.ext
prefix_20140301_085031.ext
site_name_20140301_085031.mp3

p1_s1_u1_d20140301_t000000Z.ext
p745_s2745_u951108_d20140228_t235959Z.ext

=end

end