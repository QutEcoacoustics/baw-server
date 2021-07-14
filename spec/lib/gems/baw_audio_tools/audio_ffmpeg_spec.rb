# frozen_string_literal: true



describe BawAudioTools::AudioFfmpeg do
  include_context 'common'
  include_context 'audio base'
  include_context 'temp media files'
  include_context 'test audio files'

  let(:analyse_duration) { '[wav @ 0x1d35020] max_analyze_duration 5000000 reached at 5015510 microseconds' }
  let(:estimate_duration) { '[mp3 @ 0x3279b60] Estimating duration from bitrate, this may be inaccurate' }
  let(:over_read) { '[mp3 @ 0x1edcb60] overread, skip -7 enddists: -6 -6' }
  let(:channel_layout) { "[mp3 @ 0x327a5c0] Channel layout 'mono' with 1 channels does not match specified number of channels 2: ignoring specified channel layout" }
  let(:bytes_of_junk) { '[mp3 @ 0x2679c00] Skipping 0 bytes of junk at 0.' }
  let(:unknown_warning) { "[wav @ 0x1d35020] hello I'm an unknown warning" }

  let(:frame_size_error_1) { "\n[null @ 0x5477dc0] Could not find codec parameters for stream 0 (Audio: mp3, 0 channels, s16p): unspecified frame size" }
  let(:frame_size_error_2) { "\n[null @ 0x5477dc0] Failed to read frame size: Could not seek to 1026." }

  # join using $/ (new line separator)
  let(:error_msg) { [analyse_duration, estimate_duration, over_read, channel_layout, bytes_of_junk, unknown_warning].shuffle.join($INPUT_RECORD_SEPARATOR) }

  it 'removes known warnings' do
    expect {
      audio_base.audio_ffmpeg.check_for_errors({ stderr: error_msg })
    }.to_not raise_error
  end

  it 'raises on frame size type 1 errors' do
    expected_error_msg = "Ffmpeg could not get frame size (msg type 1).\n\tExternal program output"
    expect {
      audio_base.audio_ffmpeg.check_for_errors({ stderr: "#{error_msg}#{frame_size_error_1}", execute_msg: 'External program output' })
    }.to raise_error(BawAudioTools::Exceptions::FileCorruptError, expected_error_msg)
  end

  it 'raises on frame size type 2 errors' do
    expected_error_msg = "Ffmpeg could not get frame size (msg type 2).\n\tExternal program output"
    expect {
      audio_base.audio_ffmpeg.check_for_errors({ stderr: "#{error_msg}#{frame_size_error_2}", execute_msg: 'External program output' })
    }.to raise_error(BawAudioTools::Exceptions::FileCorruptError, expected_error_msg)
  end
end
