# frozen_string_literal: true

require 'workers_helper'
require_relative '../../../helpers/baw_audio_tools_shared'

describe BawAudioTools::AudioBase do
  include_context 'audio base'
  include_context 'temp media files'

  it 'can cut accurately' do
    # Method:
    # 1. open the target file in audacity,
    # 2. find an interesting segment
    # 3. cut the segment with audacity
    # 4. Run sox <segment> -n stat
    # 5. recorded results here
    #
    # Then the test simulates the same operation with ffmpeg and runs sox stat
    # to compare the results.

    sox_stat_expected = {
      stderr: <<~INFO
        Samples read:            661500
        Length (seconds):     30.000000
        Scaled by:         2147483647.0
        Maximum amplitude:     0.941650
        Minimum amplitude:    -0.591034
        Midline amplitude:     0.175308
        Mean    norm:          0.026814
        Mean    amplitude:    -0.000207
        RMS     amplitude:     0.052841
        Maximum delta:         0.052948
        Minimum delta:         0.000000
        Mean    delta:         0.004789
        RMS     delta:         0.006271
        Rough   frequency:          416
        Volume adjustment:        1.062
      INFO
    }
    expected_cut_point = 3600 + (5 * 60)
    expected_cut_duration = 30

    cut_file = temp_file(extension: '.wav')
    audio_base.modify(
      Fixtures.bar_lt_file,
      cut_file,
      {
        start_offset: expected_cut_point,
        end_offset: expected_cut_point + expected_cut_duration
      }
    )

    expect(cut_file).to exist

    sox_stat_cmd = audio_base.audio_sox.info_command_stat(cut_file)
    sox_stat_actual = audio_base.run_program.execute(sox_stat_cmd)

    expected = audio_base.audio_sox.parse_info_output(sox_stat_expected)
    actual = audio_base.audio_sox.parse_info_output(sox_stat_actual)

    expect(expected).to eq(actual)
  end
end
