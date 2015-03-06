require 'spec_helper'

describe BawAudioTools::AudioFfmpeg do
  include_context 'common'
  include_context 'audio base'
  include_context 'temp media files'
  include_context 'test audio files'

  let(:analyse_duration) { '[wav @ 0x1d35020] max_analyze_duration 5000000 reached at 5015510 microseconds' }
  let(:estimate_duration) { '[mp3 @ 0x3279b60] Estimating duration from bitrate, this may be inaccurate' }
  let(:over_read) { '[mp3 @ 0x1edcb60] overread, skip -7 enddists: -6 -6' }
  let(:channel_layout) { "[mp3 @ 0x327a5c0] Channel layout 'mono' with 1 channels does not match specified number of channels 2: ignoring specified channel layout" }
  let(:unknown_warning) { "[wav @ 0x1d35020] hello I'm an unknown warning" }

  let(:error_msg) { "#{analyse_duration}#{estimate_duration}#{over_read}#{channel_layout}" }

  it 'removes known warnings' do
    expect {
      audio_base.audio_ffmpeg.check_for_errors({stderr: error_msg})
    }.to_not raise_error
  end

  it 'raises unknown warnings' do

    expected_error_msg = "Ffmpeg output contained warning (e.g. [mp3 @ 0x2935600]).\n\ttesting error"
    expect {
      audio_base.audio_ffmpeg.check_for_errors({stderr: "#{error_msg}#{unknown_warning}", execute_msg: 'testing error'})
    }.to raise_error(BawAudioTools::Exceptions::FileCorruptError, expected_error_msg)
  end
end