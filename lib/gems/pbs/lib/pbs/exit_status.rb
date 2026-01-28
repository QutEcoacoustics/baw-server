# frozen_string_literal: true

module PBS
  # https://github.com/openpbs/openpbs/blob/618c69f06e3580cf099b676ea0e437b98006d376/src/include/job.h#L967
  # https://2026.help.altair.com/2026.0/PBS%20Professional/PBSReference2026.0.pdf RG-386
  module ExitStatus
    # qdel cancellation is done via a SIGTERM
    CANCELLED_EXIT_STATUS = 256 + Signal.list['TERM']

    PBS_SPECIAL = (..-1)
    NORMAL = 0...256
    SIGNAL_KILL = (256..)

    JOB_EXEC_OK = 0
    JOB_EXEC_FAIL1 = -1
    JOB_EXEC_FAIL2 = -2
    JOB_EXEC_RETRY = -3
    JOB_EXEC_INITABT = -4
    JOB_EXEC_INITRST = -5
    JOB_EXEC_INITRMG = -6
    JOB_EXEC_BADRESRT = -7
    JOB_EXEC_FAILUID = -10
    JOB_EXEC_RERUN = -11
    JOB_EXEC_CHKP = -12
    JOB_EXEC_FAIL_PASSWORD = -13
    JOB_EXEC_RERUN_SIS_FAIL = -14
    JOB_EXEC_QUERST = -15
    JOB_EXEC_FAILHOOK_RERUN = -16
    JOB_EXEC_FAILHOOK_DELETE = -17
    JOB_EXEC_HOOK_RERUN = -18
    JOB_EXEC_HOOK_DELETE = -19
    JOB_EXEC_RERUN_MS_FAIL = -20
    JOB_EXEC_FAIL_SECURITY = -21
    JOB_EXEC_HOOKERROR = -22
    JOB_EXEC_FAIL_KRB5 = -23
    JOB_EXEC_UPDATE_ALPS_RESV_ID = 1
    JOB_EXEC_KILL_NCPUS_BURST = -24
    JOB_EXEC_KILL_NCPUS_SUM = -25
    JOB_EXEC_KILL_VMEM = -26
    JOB_EXEC_KILL_MEM = -27
    JOB_EXEC_KILL_CPUT = -28
    JOB_EXEC_KILL_WALLTIME = -29
    JOB_EXEC_JOINJOB = -30
    JOB_EXEC_KILL_HPMEM = -31
    JOB_EXEC_RERUN_ZOMBIE_JOB = -32

    MAP = {
      JOB_EXEC_OK => 'job exec successful',
      JOB_EXEC_FAIL1 => 'Job exec failed, before files, no retry',
      JOB_EXEC_FAIL2 => 'Job exec failed, after files, no retry ',
      JOB_EXEC_RETRY => 'Job execution failed, do retry   ',
      JOB_EXEC_INITABT => 'Job aborted on MOM initialization',
      JOB_EXEC_INITRST => 'Job aborted on MOM init, chkpt, no migrate',
      JOB_EXEC_INITRMG => 'Job aborted on MOM init, chkpt, ok migrate',
      JOB_EXEC_BADRESRT => 'Job restart failed',
      JOB_EXEC_FAILUID => 'invalid uid/gid for job',
      JOB_EXEC_RERUN => 'Job rerun',
      JOB_EXEC_CHKP => 'Job was checkpointed and killed',
      JOB_EXEC_FAIL_PASSWORD => 'Job failed due to a bad password',
      JOB_EXEC_RERUN_SIS_FAIL => 'Job rerun',
      JOB_EXEC_QUERST => 'requeue job for restart from checkpoint',
      JOB_EXEC_FAILHOOK_RERUN => 'job exec failed due to a hook rejection, requeue job for later retry (usually returned by the "early" hooks"',
      JOB_EXEC_FAILHOOK_DELETE => 'job exec failed due to a hook rejection, delete the job at end',
      JOB_EXEC_HOOK_RERUN => 'a hook requested for job to be requeued',
      JOB_EXEC_HOOK_DELETE => 'a hook requested for job to be deleted',
      JOB_EXEC_RERUN_MS_FAIL => 'Mother superior connection failed',
      JOB_EXEC_FAIL_SECURITY => 'Security breach in PBS directory',
      JOB_EXEC_HOOKERROR => 'job exec failed due to unexpected exception or hook execution timed out',
      JOB_EXEC_FAIL_KRB5 => 'Error no kerberos credentials supplied',
      JOB_EXEC_UPDATE_ALPS_RESV_ID => 'Update ALPS reservation ID to parent mom as soon as it is available. This is neither a success nor a failure exit code, so we are using a positive value',
      JOB_EXEC_KILL_NCPUS_BURST => 'job exec failed due to exceeding ncpus (burst)',
      JOB_EXEC_KILL_NCPUS_SUM => 'job exec failed due to exceeding ncpus (sum)',
      JOB_EXEC_KILL_VMEM => 'job exec failed due to exceeding vmem',
      JOB_EXEC_KILL_MEM => 'job exec failed due to exceeding mem',
      JOB_EXEC_KILL_CPUT => 'job exec failed due to exceeding cput',
      JOB_EXEC_KILL_WALLTIME => 'job exec failed due to exceeding walltime',
      JOB_EXEC_JOINJOB => 'Job exec failed due to join job error',
      JOB_EXEC_KILL_HPMEM => 'Job exec failed due to exceeding hpmem',
      JOB_EXEC_RERUN_ZOMBIE_JOB => 'Job execution hung due to re-imaged mom or lost job info from MoM'
    }.freeze

    def self.map(exit_status)
      return nil if exit_status.nil?

      # no comment / reason needed for OK or cancelled
      return nil if exit_status == JOB_EXEC_OK
      return nil if exit_status == CANCELLED_EXIT_STATUS

      return "Script failed. Exit status #{exit_status}" if NORMAL.include?(exit_status)

      # map the exit status to a comment / reason
      MAP[exit_status]
    end
  end
end
