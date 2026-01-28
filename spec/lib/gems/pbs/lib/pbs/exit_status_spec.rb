# frozen_string_literal: true

describe PBS::ExitStatus do
  describe 'constants' do
    it 'defines all expected exit status codes' do
      expect(PBS::ExitStatus::JOB_EXEC_OK).to eq 0
      expect(PBS::ExitStatus::JOB_EXEC_FAIL1).to eq(-1)
      expect(PBS::ExitStatus::JOB_EXEC_FAIL2).to eq(-2)
      expect(PBS::ExitStatus::JOB_EXEC_KILL_WALLTIME).to eq(-29)
      expect(PBS::ExitStatus::JOB_EXEC_JOINJOB).to eq(-30)
      expect(PBS::ExitStatus::JOB_EXEC_KILL_HPMEM).to eq(-31)
      expect(PBS::ExitStatus::JOB_EXEC_RERUN_ZOMBIE_JOB).to eq(-32)
    end

    it 'defines the CANCELLED_EXIT_STATUS as SIGTERM (271)' do
      # SIGTERM is typically 15, so 256 + 15 = 271
      expect(PBS::ExitStatus::CANCELLED_EXIT_STATUS).to eq(256 + Signal.list['TERM'])
    end
  end

  describe '.map' do
    it 'returns nil for successful jobs' do
      expect(PBS::ExitStatus.map(PBS::ExitStatus::JOB_EXEC_OK)).to be_nil
    end

    it 'returns nil for cancelled jobs' do
      expect(PBS::ExitStatus.map(PBS::ExitStatus::CANCELLED_EXIT_STATUS)).to be_nil
    end

    it 'returns script failed message for normal exit codes' do
      expect(PBS::ExitStatus.map(1)).to eq 'Script failed. Exit status 1'
      expect(PBS::ExitStatus.map(127)).to eq 'Script failed. Exit status 127'
      expect(PBS::ExitStatus.map(255)).to eq 'Script failed. Exit status 255'
    end

    it 'returns descriptive messages for PBS special exit codes' do
      expect(PBS::ExitStatus.map(PBS::ExitStatus::JOB_EXEC_KILL_WALLTIME))
        .to eq 'job exec failed due to exceeding walltime'
      expect(PBS::ExitStatus.map(PBS::ExitStatus::JOB_EXEC_FAILHOOK_DELETE))
        .to eq 'job exec failed due to a hook rejection, delete the job at end'
      expect(PBS::ExitStatus.map(PBS::ExitStatus::JOB_EXEC_RERUN_MS_FAIL))
        .to eq 'Mother superior connection failed'
      expect(PBS::ExitStatus.map(PBS::ExitStatus::JOB_EXEC_KILL_HPMEM))
        .to eq 'Job exec failed due to exceeding hpmem'
      expect(PBS::ExitStatus.map(PBS::ExitStatus::JOB_EXEC_RERUN_ZOMBIE_JOB))
        .to eq 'Job execution hung due to re-imaged mom or lost job info from MoM'
    end

    it 'returns nil for unknown PBS special exit codes' do
      # If a new PBS code is added that we don't know about, it will return nil
      # rather than crashing. The code will still be handled as :killed by map_exit_status_to_state
      expect(PBS::ExitStatus.map(-999)).to be_nil
    end
  end
end

describe PBS::Connection do
  describe '.map_exit_status_to_state' do
    it 'returns nil for nil exit status' do
      expect(PBS::Connection.map_exit_status_to_state(nil)).to be_nil
    end

    it 'returns :success for JOB_EXEC_OK (0)' do
      expect(PBS::Connection.map_exit_status_to_state(0)).to eq :success
    end

    it 'returns :killed for all PBS special (negative) exit codes' do
      # Issue #875 - JOB_EXEC_KILL_WALLTIME
      expect(PBS::Connection.map_exit_status_to_state(-29)).to eq :killed
      # Issue #878 - JOB_EXEC_FAILHOOK_DELETE
      expect(PBS::Connection.map_exit_status_to_state(-17)).to eq :killed
      # Issue #879 - JOB_EXEC_RERUN_ZOMBIE_JOB
      expect(PBS::Connection.map_exit_status_to_state(-32)).to eq :killed
      # Issue #880 - JOB_EXEC_RERUN_MS_FAIL
      expect(PBS::Connection.map_exit_status_to_state(-20)).to eq :killed
      # New code - JOB_EXEC_KILL_HPMEM
      expect(PBS::Connection.map_exit_status_to_state(-31)).to eq :killed
      # Other codes
      expect(PBS::Connection.map_exit_status_to_state(-1)).to eq :killed
      expect(PBS::Connection.map_exit_status_to_state(-100)).to eq :killed
    end

    it 'returns :failed for normal exit codes (1-255)' do
      expect(PBS::Connection.map_exit_status_to_state(1)).to eq :failed
      expect(PBS::Connection.map_exit_status_to_state(127)).to eq :failed
      expect(PBS::Connection.map_exit_status_to_state(255)).to eq :failed
    end

    it 'returns :cancelled for SIGTERM (271)' do
      expect(PBS::Connection.map_exit_status_to_state(PBS::ExitStatus::CANCELLED_EXIT_STATUS)).to eq :cancelled
    end

    it 'returns :killed for signal exit codes (256+)' do
      expect(PBS::Connection.map_exit_status_to_state(256)).to eq :killed
      expect(PBS::Connection.map_exit_status_to_state(300)).to eq :killed
    end

    it 'raises ArgumentError for non-integer exit status' do
      expect {
        PBS::Connection.map_exit_status_to_state('not an integer')
      }.to raise_error(ArgumentError, /exit_status .* must be an Integer/)
    end
  end
end
