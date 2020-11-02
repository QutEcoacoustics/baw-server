# frozen_string_literal: true

require 'workers_helper'
require_relative '../../../helpers/shared_context/baw_audio_tools_shared'

describe BawAudioTools::AudioBase do
  include_context 'audio base'
  include_context 'temp media files'

  before do
    path = Pathname(Settings.paths.temp_dir) / 'big.flac'

    path.unlink if path.exist? || path.symlink?
    path.parent.mkpath

    path.make_symlink(Fixtures.bar_lt_file)

    @test_file = path
  end

  after do
    @test_file&.unlink
  end

  it 'can modify files that are symlinks pointing to real files' do
    modified_file = temp_file(extension: '.wav')
    result = audio_base.modify(
      @test_file,
      modified_file,
      { start_offset: 0, end_offset: 30 }
    )

    expect(result).to be nil

    info = audio_base.info(modified_file)

    expect(info).to match(a_hash_including({
      data_length_bytes: 1_323_078,
      media_type: 'audio/wav',
      sample_rate: 22_050.0,
      channels: 1,
      duration_seconds: be_within(1.0).of(30.0),
      bit_rate_bps: be_within(400).of(352_800)
    }))
  end

  it 'can get info for files that are symlinks pointing to real files' do
    info = audio_base.info(
      @test_file
    )

    expect(info).to match(a_hash_including({
      data_length_bytes: 181_671_228,
      media_type: 'audio/x-flac',
      sample_rate: 22_050,
      channels: 1,
      duration_seconds: be_within(1.0).of(7194),
      bit_rate_bps: be_within(400).of(202_004)
    }))
  end
end
