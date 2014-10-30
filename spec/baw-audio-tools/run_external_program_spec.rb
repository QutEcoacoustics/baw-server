require 'spec_helper'

describe BawAudioTools::RunExternalProgram do
  include_context 'common'

  it 'check timeout is enforced' do
    run_program = BawAudioTools::RunExternalProgram.new(3, logger)

    command = 'sleep 120'
    expect {
      run_program.execute(command)
    }.to raise_error(BawAudioTools::Exceptions::AudioToolTimedOutError, /#{command}/)
  end

  it 'check timeout does not impact successful execution' do
    run_program = BawAudioTools::RunExternalProgram.new(
        RSpec.configuration.test_settings.audio_tools_timeout_sec,
        logger)

    sleep_duration = 1
    command = "sleep #{sleep_duration}"

    result = run_program.execute(command)

    expect(result[:time_taken]).to be_within(sleep_range).of(sleep_duration)
    expect(result[:stdout]).to be_blank
    expect(result[:stderr]).to be_blank
    expect(result[:command]).to eq(command)
    expect(result[:exit_code]).to eq(0)
    expect(result[:execute_msg]).to match(/External Program: status=0;killed=false;time_out_sec=10;time_taken_sec=1/)
  end
end