# frozen_string_literal: true

require 'workers_helper'
require_relative '../../../helpers/shared_context/baw_audio_tools_shared'
require 'benchmark'

describe BawAudioTools::AudioBase do
  include_context 'audio base'
  include_context 'temp media files'

  let(:fast_cut_time) {
    3.0
  }

  it 'the seek+cut operation is quick (at the start)' do
    expect { |_sample|
      audio_base.modify(
        Fixtures.bar_lt_file,
        temp_file(extension: '.wav'),
        { start_offset: 0, end_offset: 30 }
      )
    }.to perform_under(fast_cut_time).sec.sample(5).times
  end

  it 'the seek+cut operation is quick (at the end)' do
    expect { |_sample|
      audio_base.modify(
        Fixtures.bar_lt_file,
        temp_file(extension: '.wav'),
        { start_offset: 7100, end_offset: 7130 }
      )
    }.to perform_under(fast_cut_time).sec.sample(5).times
  end

  it 'has a O(1) seek+cut performance profile' do
    # every 15 minutes, until near the end of the file
    offsets = 0.step(7140, 900).to_a

    real_times = offsets.map { |offset|
      time = Benchmark.measure {
        audio_base.modify(
          Fixtures.bar_lt_file,
          temp_file(extension: '.wav'),
          { start_offset: offset, end_offset: offset + 30 }
        )
      }
      puts "offset: #{offset}: #{time.real}"
      time.real
    }

    stats = DescriptiveStatistics::Stats.new(real_times)

    # This doesn't strictly test for a constant variable with noise.
    # But, the bounds are narrow enough that the test failed previously when seek time in ffmpeg was linear
    expect(stats.mean).to be_within(0.2).of(0.64)
    expect(stats.variance).to be_within(0.1).of(0.02)
    expect(stats.standard_deviation).to be_within(0.1).of(0.03)
  end
end
