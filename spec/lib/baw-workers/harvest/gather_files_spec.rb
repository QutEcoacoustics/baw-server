require 'spec_helper'

describe BawWorkers::Harvest::GatherFiles do
  include_context 'shared_test_helpers'

  let(:config_file_name) { BawWorkers::Settings.actions.harvest.config_file_name }

  let(:file_info) { BawWorkers::Config.file_info }

  let(:gather_files) {
    BawWorkers::Harvest::GatherFiles.new(
        BawWorkers::Config.logger_worker,
        file_info,
        BawWorkers::Settings.available_formats.audio,
        config_file_name
    )
  }

  let(:example_audio) { audio_file_mono }


  let(:folder_example) { File.expand_path File.join(File.dirname(__FILE__), 'folder_example.yml') }

  context 'parse file name' do

=begin
    For: Harvester::AudioFile.get_file_info_from_name
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


    it 'should error if the file does not exist' do
      file_name = 'blah.ext'
      expect(File.exists?(file_name)).to be_falsey
      expect(file_info.advanced(file_name, '+03')).to be_blank
    end

    it 'should parse a date and time without offset file name correctly' do
      file_name = 'site_name_20140301_085031.mp3'
      result = file_info.advanced(file_name, '+11')

      expect(result[:recorded_date]).to eq(DateTime.new(2014, 3, 1, 8, 50, 31, '+11').iso8601(3))
      expect(result[:utc_offset]).to eq('+11')
      expect(result[:prefix]).to eq('site_name')
      expect(result[:extension]).to eq('mp3')
    end

    it 'should parse a date and time without offset without prefix file name correctly' do
      file_name = '20140301_085031.mp3'
      result = file_info.advanced(file_name, '+11')

      expect(result[:recorded_date]).to eq(DateTime.new(2014, 3, 1, 8, 50, 31, '+11').iso8601(3))
      expect(result[:utc_offset]).to eq('+11')
      expect(result[:prefix]).to eq('')
      expect(result[:extension]).to eq('mp3')
    end

    it 'should parse a date and time with offset file name correctly' do
      file_name = 'site_name_20140301_085031+11.mp3'
      result = file_info.advanced(file_name)

      expect(result[:recorded_date]).to eq(DateTime.new(2014, 3, 1, 8, 50, 31, '+11').iso8601(3))
      expect(result[:utc_offset]).to eq('+11')
      expect(result[:prefix]).to eq('site_name')
      expect(result[:extension]).to eq('mp3')
    end

    it 'should parse a date and time with offset without prefix file name correctly' do
      file_name = '20140301_085031+11.mp3'
      result = file_info.advanced(file_name)

      expect(result[:recorded_date]).to eq(DateTime.new(2014, 3, 1, 8, 50, 31, '+11').iso8601(3))
      expect(result[:utc_offset]).to eq('+11')
      expect(result[:prefix]).to eq('')
      expect(result[:extension]).to eq('mp3')
    end

    it 'should fail to parse a file without a matching file name' do
      file_name = 'my_audio_file.mp3'
      expect(file_info.advanced(file_name, '+0')).to be_blank
    end

    it 'should parse a regular ALL THE INFO! file name correctly' do
      file_name = 'p143_s254_u1045_d20140228_t235959Z.wav'
      result = file_info.advanced(file_name)

      expect(result[:recorded_date]).to eq(DateTime.new(2014, 2, 28, 23, 59, 59, '+0').iso8601(3))
      expect(result[:utc_offset]).to eq('+0')
      expect(result[:project_id]).to eq(143)
      expect(result[:site_id]).to eq(254)
      expect(result[:uploader_id]).to eq(1045)
      expect(result[:extension]).to eq('wav')
    end

    it 'should parse a prefixed and suffixed file name correctly' do
      file_name = 'SERF_20130314_000021_000.wav'
      result = file_info.advanced(file_name, '+0')

      expect(result[:recorded_date]).to eq(DateTime.new(2013, 3, 14, 0, 0, 21, '+0').iso8601(3))
      expect(result[:utc_offset]).to eq('+0')
      expect(result[:extension]).to eq('wav')
      expect(result[:prefix]).to eq('SERF')
      expect(result[:suffix]).to eq('000')
    end
  end

  context 'get file info' do

    let(:result) { file_info.basic(example_audio) }

    it 'should match full path' do
      expect(result[:file_path]).to eq(example_audio)
    end

    it 'should match file name' do
      expect(result[:file_name]).to eq(File.basename(example_audio))
    end

    it 'should match file extension' do
      expect(result[:extension]).to eq(File.extname(example_audio).trim('.', ''))
    end

    it 'should match file access time' do
      expect(result[:access_time]).to eq(File.atime(example_audio))
    end

    it 'should match file change time' do
      expect(result[:change_time]).to eq(File.ctime(example_audio))
    end

    it 'should match modified extension' do
      expect(result[:modified_time]).to eq(File.mtime(example_audio))
    end

    it 'should match file size' do
      expect(result[:data_length_bytes]).to eq(File.size(example_audio))
    end

  end

  context 'settings values' do
    it 'should fail if value is not numeric' do
      expect(file_info.numeric?('10')).to be_falsey
    end

    it 'should succeed if value is numeric' do
      expect(file_info.numeric?(4)).to be_truthy
    end

    it 'should fail if value is not a time offset' do
      expect(file_info.time_offset?('4')).to be_falsey
    end

    it 'should succeed if value is a time offset' do
      expect(file_info.time_offset?('+10')).to be_truthy
    end

    it 'should succeed if value is a time offset' do
      expect(file_info.time_offset?('+1000')).to be_truthy
    end

    it 'should succeed if value is a time offset' do
      expect(file_info.time_offset?('+10:00')).to be_truthy
    end
  end

  context 'get folder settings' do
    it 'should fail if file does not exist' do
      sub_folder = File.join(harvest_to_do_path, 'settings_do_not_exist')
      FileUtils.mkpath(sub_folder)
      file = File.join(sub_folder, config_file_name)
      expect(gather_files.run(file)).to be_empty
    end

    it 'should succeed if file does exist' do
      audio_file = File.expand_path audio_file_mono
      sub_folder = File.expand_path File.join(harvest_to_do_path, 'harvest_file_exists')

      FileUtils.mkpath(sub_folder)
      dir_config = File.join(sub_folder, 'harvest.yml')
      FileUtils.copy(folder_example, dir_config)

      audio_file_config = File.join(sub_folder, 'test_20141010_101010.ogg')
      FileUtils.copy(audio_file, audio_file_config)

      settings = gather_files.run(harvest_to_do_path)
      expect(settings.size).to eq(1)
      expect(settings[0]).not_to be_empty
      expect(settings[0][:project_id]).to eq(10)
      expect(settings[0][:site_id]).to eq(20)
      expect(settings[0][:uploader_id]).to eq(30)
      expect(settings[0][:utc_offset]).to eq('+10')
      expect(settings[0][:file_rel_path]).to eq('harvest_file_exists/test_20141010_101010.ogg')
      #FileUtils.rm(sub_folder)
    end
  end

  context 'get file info' do

    it 'should reject directories' do
      sub_folder = File.join(harvest_to_do_path, 'one')
      FileUtils.mkpath(File.join(sub_folder, 'two', 'three'))
      FileUtils.mkpath(File.join(sub_folder, 'two', 'four'))
      expect(gather_files.run(harvest_to_do_path)).to be_empty
    end

    it 'should error on read-only directories' do
      sub_folder = File.join(harvest_to_do_path, 'one')
      three = File.join(sub_folder, 'two', 'three')
      four = File.join(sub_folder, 'two', 'four')
      FileUtils.mkpath(three)
      FileUtils.mkpath(four, mode: 0400)
      expect {
        gather_files.run(harvest_to_do_path)
      }.to raise_error(ArgumentError, /Found read-only directory: /)
      FileUtils.rm_rf(sub_folder, secure: true)
    end

    it 'should skip log files' do
      sub_folder = File.join(harvest_to_do_path, 'one')
      FileUtils.mkpath(sub_folder)
      FileUtils.touch(File.join(sub_folder, 'amazing_thingo.log'))
      FileUtils.touch(File.join(sub_folder, 'my_file_pls.log'))
      expect(gather_files.run(harvest_to_do_path)).to be_empty
    end

    it 'should skip folder settings file' do
      sub_folder = File.join(harvest_to_do_path, 'one')
      FileUtils.mkpath(sub_folder)
      FileUtils.cp(folder_example, File.join(sub_folder, 'harvest.yml'))
      expect(gather_files.run(harvest_to_do_path)).to be_empty
    end

    it 'should include other files' do
      sub_folder = File.join(harvest_to_do_path, 'one')
      FileUtils.mkpath(sub_folder)
      FileUtils.cp(folder_example, File.join(sub_folder, 'harvest.yml'))
      FileUtils.touch(File.join(sub_folder, 'amazing_thingo.log'))
      FileUtils.mkpath(File.join(sub_folder, 'two', 'three'))

      FileUtils.touch(File.join(sub_folder, 'a file.txt'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'some sound.mp3'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'around your head.flac'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'around your head.wav'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'around your head.ogg'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'around your head.webm'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'around your head.asf'))

      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'two', 'p1_s2_u3_d20140101_t235959Z.mp3'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'two', 'p000_s00000_u00000_d00000000_t000000Z.0'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'two', 'p9999_s9_u9999999_d99999999_t999999Z.ogg'))

      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'prefix_20140101_235959.mp3'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'a_00000000_000000.a'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'a_99999999_999999.dnsb48364JSFDSD'))

      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'two', 'three', 'prefix_20140101_235959+10.mp3'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'a_00000000_000000+00.a'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'a_99999999_999999+9999.dnsb48364JSFDSD'))

      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'SERF_20130314_000021_000.wav'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'a_20130314_000021_a.a'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'two', 'three', 'a_99999999_999999_a.dnsb48364JSFDSD'))

      results = gather_files.run(harvest_to_do_path)

      expect(results.size).to eq(4)

      expect(results[0]).to include(:metadata)
      expect(results[0][:file_rel_path]).to eq('one/prefix_20140101_235959.mp3')

      expect(results[1]).to include(:metadata)
      expect(results[1][:file_rel_path]).to eq('one/SERF_20130314_000021_000.wav')

      expect(results[2]).to_not include(:metadata)
      expect(results[2][:file_rel_path]).to eq('one/two/p1_s2_u3_d20140101_t235959Z.mp3')

      expect(results[3]).to_not include(:metadata)
      expect(results[3][:file_rel_path]).to eq('one/two/three/prefix_20140101_235959+10.mp3')
    end

    it 'should error on read-only directory' do
      sub_folder = File.join(harvest_to_do_path, 'one')
      FileUtils.mkpath(sub_folder)
      FileUtils.cp(folder_example, File.join(sub_folder, 'harvest.yml'))
      FileUtils.touch(File.join(sub_folder, 'amazing_thingo.log'))
      FileUtils.mkpath(File.join(sub_folder, 'read_only'), mode: 0400)

      FileUtils.touch(File.join(sub_folder, 'a file.txt'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'some sound.mp3'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'around your head.flac'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'around your head.wav'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'around your head.ogg'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'around your head.webm'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'around your head.asf'))

      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'p1_s2_u3_d20140101_t235959Z.mp3'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'p000_s00000_u00000_d00000000_t000000Z.0'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'p9999_s9_u9999999_d99999999_t999999Z.ogg'))

      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'prefix_20140101_235959.mp3'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'a_00000000_000000.a'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'a_99999999_999999.dnsb48364JSFDSD'))

      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'prefix_20140101_235959+10.mp3'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'a_00000000_000000+00.a'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'a_99999999_999999+9999.dnsb48364JSFDSD'))

      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'SERF_20130314_000021_000.wav'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'a_20130314_000021_a.a'))
      FileUtils.cp(audio_file_mono, File.join(sub_folder, 'a_99999999_999999_a.dnsb48364JSFDSD'))

      expect {
        gather_files.run(harvest_to_do_path)
      }.to raise_error(ArgumentError, /Found read-only directory: /)

      FileUtils.rm_rf(sub_folder, secure: true)
    end

  end

end