require 'spec_helper'

describe BawAudioTools::RunExternalProgram do
  include_context 'common'

  def test_is_not_running(message)
    # get pid and check if that pid is still running
    pid = message.match(/;pid=([0-9]+);/).captures[0]

    # 0 = A value of 0 will cause error checking to be performed (with no signal being sent).
    # This can be used to check the validity of pid.
    is_running = (!!Process.kill(0, pid) rescue false)

    expect(is_running).to be_falsey
  end

  it 'check timeout is enforced' do
    run_program = BawAudioTools::RunExternalProgram.new(3, logger)

    command = 'sleep 120'
    error = nil

    begin
      run_program.execute(command)
    rescue => e
      error = e
    end

    expect(error).to be_a(BawAudioTools::Exceptions::AudioToolTimedOutError)
    expect(error.message).to match(/#{command}/)

    test_is_not_running(error.message)
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
    expect(result[:execute_msg]).to match(/External Program: status=0;killed=false;pid=[0-9]+;time_out_sec=10;time_taken_sec=1/)
  end

  it 'ensures non-zero exit codes are treated as failures' do
    run_program = BawAudioTools::RunExternalProgram.new(100, logger)

    # it is important this command does not output anything to stderr but still fails
    command = "bash -c 'exit 255'"
    error = nil

    begin
      run_program.execute(command)
    rescue => e
      error = e
    end

    expect(error).to be_a(BawAudioTools::Exceptions::AudioToolError)
    expect(error.message).to match(/#{command}/)

    test_is_not_running(error.message)
  end

  it 'ensures non-zero exit codes can be ignored as failures' do
    run_program = BawAudioTools::RunExternalProgram.new(100, logger)

    command = "bash -c 'exit 255'"
    error = nil
    raise_exit_error = false

    result = run_program.execute(command, raise_exit_error)


    expect(result[:exit_code]).to eq(255)
    expect(result[:success]).to eq(false)
    expect(result[:execute_msg]).to match(/#{command}/)

    test_is_not_running(result[:execute_msg])
  end


end