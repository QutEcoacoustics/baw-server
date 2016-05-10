require 'spec_helper'

def expect_invalid_file_name(file_name)
  it file_name do |example|
    file_name = example.metadata[:description]
    result = nil
    expect {
      result = file_info.file_name_datetime(file_name, '+00:00')

    }.to raise_error(ArgumentError, 'invalid date'), "Expected error for #{file_name}, got #{result}."
  end
end

def expect_empty_file_name(file_name)
  it file_name do |example|
    file_name = example.metadata[:description]
    expect(file_info.file_name_datetime(file_name, '+00:00')).to be_empty
  end
end

def expect_correct_file_name(file_name, expected_hash)
  it file_name do |example|
    file_name = example.metadata[:description]

    result = file_info.file_name_datetime(file_name, '+00:00')
    expected_result = expected_hash
    expect(result).to eq(expected_result)

    unless ['20150727T133138Z.wav',
            'blah_T-suffix20140301-085031-7s:dncv*_-T&^%34jd.ext',
            'sdncv*_-T&^%34jd_20140301_085031-0630blah_T-suffix.mp3',
            'sdncv*_-T&^%34jd_20140301_085031+06:30blah_T-suffix.mp3'].include?(file_name)
      expect {
        file_info.file_name_datetime(file_name)
      }.to raise_error(
               BawWorkers::Exceptions::HarvesterConfigurationError,
               'No UTC offset provided and file name did not contain a utc offset.')
    end
  end
end

describe BawWorkers::FileInfo do
  include_context 'shared_test_helpers'

  let(:file_info) { BawWorkers::Config.file_info }

  context 'parse file name with all info' do

    it 'p1_s2_u3_d20140101_t235959Z.mp3' do |example|
      file_name = example.metadata[:description]
      result = file_info.file_name_all(file_name)
      expected_result =
          {raw:
               {
                   project_id: '1', site_id: '2', uploader_id: '3',
                   year: '2014', month: '01', day: '01',
                   hour: '23', min: '59', sec: '59',
                   offset: 'Z', ext: 'mp3'
               },
           project_id: 1, site_id: 2, uploader_id: 3,
           utc_offset: 'Z',
           recorded_date: '2014-01-01T23:59:59.000+00:00',
           prefix: '', separator: '_', suffix: '',
           extension: 'mp3'
          }

      expect(result).to eq(expected_result)
    end

    it 'p1_s1_u1_d20140301_t000000Z.ext' do |example|
      file_name = example.metadata[:description]
      result = file_info.file_name_all(file_name)
      expected_result =
          {raw:
               {
                   project_id: '1', site_id: '1', uploader_id: '1',
                   year: '2014', month: '03', day: '01',
                   hour: '00', min: '00', sec: '00',
                   offset: 'Z', ext: 'ext'
               },
           project_id: 1, site_id: 1, uploader_id: 1,
           utc_offset: 'Z',
           recorded_date: '2014-03-01T00:00:00.000+00:00',
           prefix: '', separator: '_', suffix: '',
           extension: 'ext'
          }

      expect(result).to eq(expected_result)
    end

    it 'p745_s2745_u951108_d20140228_t235959Z.ext' do |example|
      file_name = example.metadata[:description]
      result = file_info.file_name_all(file_name)
      expected_result =
          {raw:
               {
                   project_id: '745', site_id: '2745', uploader_id: '951108',
                   year: '2014', month: '02', day: '28',
                   hour: '23', min: '59', sec: '59',
                   offset: 'Z', ext: 'ext'
               },
           project_id: 745, site_id: 2745, uploader_id: 951108,
           utc_offset: 'Z',
           recorded_date: '2014-02-28T23:59:59.000+00:00',
           prefix: '', separator: '_', suffix: '',
           extension: 'ext'
          }

      expect(result).to eq(expected_result)
    end

    it 'p000_s00000_u00000_d00000000_t000000Z.0' do |example|
      file_name = example.metadata[:description]
      expect {
        file_info.file_name_all(file_name)
      }.to raise_error(ArgumentError, 'invalid date')
    end

    it 'p9999_s9_u9999999_d99999999_t999999Z.dnsb48364JSFDSD' do |example|
      file_name = example.metadata[:description]
      expect {
        file_info.file_name_all(file_name)
      }.to raise_error(ArgumentError, 'invalid date')
    end

  end

  context 'parse file name with datetime info' do

    context 'invalid' do

      [
          'a_99999999_999999_a.dnsb48364JSFDSD',
          'a_00000000_000000.a',
          'a_00000000_000000+00.a',
          'a_99999999_999999.dnsb48364JSFDSD',
          'a_00000000-000000+00.a',
          'a_99999999_999999+9999.dnsb48364JSFDSD'
      ].each do |item|
        expect_invalid_file_name(item)
      end

      [
          '',
          'blah',
          'blah.ext',
          '.ext.ext.ext',
          'hi.hi',
          'yyyymmdd_hhmmss.ext',
          '_yyyymmdd_hhmmss.ext',
          'blah_yyyymmdd_hhmmss.ext_blah',
          'blah_yyyymmdd_hhmmss.ext_blah',
          'blah_yyyymmdd_hhmmss.ext.blah',
          'yyyymmdd_hhmmss_yyyymmdd_hhmmss.ext.blah',
          'yyyymmdd_hhmmssyyyymmdd_hhmmss.ext.blah',
          'yyyymmdd_hhmmssyyyymmdd_hhmmss.ext',
          'p1_s1_u1_d20140301_t000000.ext',
          '1_s1_u1_d20140301_t000000.ext',
          'p1_s1_1_d20140301_t000000.ext',
          'p1_s1_u1_d0140301_t000000.ext',
          'p1_s1_u1_d20140301_t00000Z.ext',
          'my_audio_file.mp3',
          'sdncv*_-T&^%34jd_20140301_-085031_blah_T-suffix.ext',
          'sdncv*_-T&^%34jd_20140301_-085031+_blah_T-suffix.ext',
          'sdncv*_-T&^%34jd_20140301_-085031:_blah_T-suffix.ext',
          'sdncv*_-T&^%34jd_20140301_-085031-_blah_T-suffix.ext'
      ].each do |item|
        expect_empty_file_name(item)
      end

    end


    context 'valid' do

      {
          'sdncv*_-T&^%34jd_20140301_085031+06:30blah_T-suffix.mp3' =>
              {raw: {
                  year: '2014', month: '03', day: '01',
                  hour: '08', min: '50', sec: '31',
                  offset: '+06:30', ext: 'mp3'
              },
               utc_offset: '+06:30',
               recorded_date: '2014-03-01T08:50:31.000+06:30',
               prefix: 'sdncv*_-T&^%34jd_', separator: '_', suffix: 'blah_T-suffix',
               extension: 'mp3'
              },
          'sdncv*_-T&^%34jd_20140301_085031-0630blah_T-suffix.mp3' =>
              {raw: {
                  year: '2014', month: '03', day: '01',
                  hour: '08', min: '50', sec: '31',
                  offset: '-0630', ext: 'mp3'
              },
               utc_offset: '-0630',
               recorded_date: '2014-03-01T08:50:31.000-06:30',
               prefix: 'sdncv*_-T&^%34jd_', separator: '_', suffix: 'blah_T-suffix',
               extension: 'mp3'
              },
          'blah_T-suffix20140301-085031-7s:dncv*_-T&^%34jd.ext' =>
              {raw: {
                  year: '2014', month: '03', day: '01',
                  hour: '08', min: '50', sec: '31',
                  offset: '-7', ext: 'ext'
              },
               utc_offset: '-7',
               recorded_date: '2014-03-01T08:50:31.000-07:00',
               prefix: 'blah_T-suffix', separator: '-', suffix: 's:dncv*_-T&^%34jd',
               extension: 'ext'
              },
          '20150727133138.wav' =>
              {raw: {
                  year: '2015', month: '07', day: '27',
                  hour: '13', min: '31', sec: '38',
                  offset: '', ext: 'wav'
              },
               utc_offset: '+00:00',
               recorded_date: '2015-07-27T13:31:38.000+00:00',
               prefix: '', separator: '', suffix: '',
               extension: 'wav'
              },
          'blah_T-suffix20140301085031:dncv*_-T&^%34jd.ext' =>
              {raw: {
                  year: '2014', month: '03', day: '01',
                  hour: '08', min: '50', sec: '31',
                  offset: '', ext: 'ext'
              },
               utc_offset: '+00:00',
               recorded_date: '2014-03-01T08:50:31.000+00:00',
               prefix: 'blah_T-suffix', separator: '', suffix: ':dncv*_-T&^%34jd',
               extension: 'ext'
              },
          'SERF_20130314_000021_000.wav' =>
              {raw: {
                  year: '2013', month: '03', day: '14',
                  hour: '00', min: '00', sec: '21',
                  offset: '', ext: 'wav'
              },
               utc_offset: '+00:00',
               recorded_date: '2013-03-14T00:00:21.000+00:00',
               prefix: 'SERF_', separator: '_', suffix: '_000',
               extension: 'wav'
              },
          '20150727T133138Z.wav' =>
              {raw: {
                  year: '2015', month: '07', day: '27',
                  hour: '13', min: '31', sec: '38',
                  offset: 'Z', ext: 'wav'
              },
               utc_offset: 'Z',
               recorded_date: '2015-07-27T13:31:38.000+00:00',
               prefix: '', separator: 'T', suffix: '',
               extension: 'wav'
              }
      }.each do |file_name, expected_hash|
        expect_correct_file_name(file_name, expected_hash)
      end

    end

  end
end