# frozen_string_literal: true

describe PBS::Transformers::StatusTransformer do
  let(:raw) {
    <<~JSON
      {
        "timestamp": 1665476097,
        "pbs_version": "22.05.11",
        "pbs_server": "725ccdf1a5fb",
        "Jobs": {
          "0.725ccdf1a5fb": {
            "Job_Name": "testname",
            "Job_Owner": "pbsuser@725ccdf1a5fb",
            "resources_used": {
              "cpupercent": 0,
              "cput": "1234:56:78.9012345",
              "mem": "7060kb",
              "ncpus": 1,
              "vmem": "512mb",
              "walltime": "00:00:00"
            },
            "job_state": "F",
            "queue": "workq",
            "server": "725ccdf1a5fb",
            "Checkpoint": "u",
            "ctime": "Tue Oct 11 08:13:45 2022",
            "depend": "beforeany:1014.905bfe60ad67@905bfe60ad67:1015.905bfe60ad67@905bfe60ad67,beforeok:1016.905bfe60ad67@905bfe60ad67",
            "Error_Path": "725ccdf1a5fb:/home/pbsuser/testname.e0",
            "exec_host": "725ccdf1a5fb/0",
            "exec_vnode": "(725ccdf1a5fb:ncpus=1)",
            "group_list": "pbsuser",
            "Hold_Types": "n",
            "Join_Path": "n",
            "Keep_Files": "n",
            "Mail_Points": "a",
            "mtime": "Tue Oct 11 08:13:47 2022",
            "Output_Path": "725ccdf1a5fb:/home/pbsuser/testname.o0",
            "Priority": 0,
            "qtime": "Tue Oct 11 08:13:45 2022",
            "Rerunable": "True",
            "Resource_List": {
              "ncpus": 1,
              "nodect": 1,
              "place": "pack",
              "select": "1:ncpus=1"
            },
            "stime": "Tue Oct 11 08:13:45 2022",
            "obittime": "Tue Oct 11 08:13:47 2022",
            "jobdir": "/home/pbsuser",
            "substate": 92,
            "Variable_List": {
              "PBS_O_HOME": "/home/pbsuser",
              "PBS_O_LANG": "en_US.UTF-8",
              "PBS_O_LOGNAME": "pbsuser",
              "PBS_O_PATH": "/home/pbsuser/bin:/usr/local/bin:/usr/bin:/bin:/opt/pbs/bin",
              "PBS_O_MAIL": "/var/mail/pbsuser",
              "PBS_O_SHELL": "/bin/bash",
              "PBS_O_WORKDIR": "/home/pbsuser",
              "PBS_O_SYSTEM": "Linux",
              "PBS_O_QUEUE": "workq",
              "PBS_O_HOST": "725ccdf1a5fb"
            },
            "comment": "Job run at Tue Oct 11 at 08:13 on (725ccdf1a5fb:ncpus=1) and finished",
            "etime": "Tue Oct 11 08:13:45 2022",
            "run_count": 1,
            "Stageout_status": 1,
            "Exit_status": 0,
            "Submit_arguments": "-N testname -",
            "history_timestamp": 1665476027,
            "project": "_pbs_project_default",
            "Submit_Host": "725ccdf1a5fb",
            "eligible_time": "00:02:10",
            "array": "True",
            "array_state_count": "Queued:999 Running:0 Exiting:0 Expired:2 ",
            "array_indices_submitted": "0-1000",
            "array_indices_remaining": "2-1000",
            "estimated": {
              "exec_vnode": "(cl4n017[0]:ncpus=8:mem=33554432kb)+(cl4n017[1]:ncpus=4)",
              "start_time": "Wed Oct 12 14:48:45 2022"
            }
          }
        }
      }
    JSON
  }

  let(:expected) {
    {
      timestamp: Time.zone.at(1_665_476_097),
      pbs_version: '22.05.11',
      pbs_server: '725ccdf1a5fb',
      jobs: {
        '0.725ccdf1a5fb' => {
          job_id: '0.725ccdf1a5fb',
          job_name: 'testname',
          job_owner: 'pbsuser@725ccdf1a5fb',
          resources_used: {
            cpupercent: 0,
            cput: 4_445_838.9012345,
            mem: 7_229_440,
            ncpus: 1,
            vmem: 536_870_912,
            walltime: 0
          },
          job_state: 'F',
          queue: 'workq',
          server: '725ccdf1a5fb',
          checkpoint: 'u',
          ctime: BawApp.utc_tz.parse('Tue Oct 11 08:13:45 2022'),
          depend: {
            beforeany: ['1014.905bfe60ad67@905bfe60ad67', '1015.905bfe60ad67@905bfe60ad67'],
            beforeok: ['1016.905bfe60ad67@905bfe60ad67']
          },
          error_path: '725ccdf1a5fb:/home/pbsuser/testname.e0',
          exec_host: '725ccdf1a5fb/0',
          exec_vnode: '(725ccdf1a5fb:ncpus=1)',
          group_list: 'pbsuser',
          hold_types: 'n',
          join_path: 'n',
          keep_files: 'n',
          mail_points: 'a',
          mtime: BawApp.utc_tz.parse('Tue Oct 11 08:13:47 2022'),
          output_path: '725ccdf1a5fb:/home/pbsuser/testname.o0',
          priority: 0,
          qtime: BawApp.utc_tz.parse('Tue Oct 11 08:13:45 2022'),
          rerunable: true,
          resource_list: {
            ncpus: 1,
            nodect: 1,
            place: 'pack',
            select: '1:ncpus=1'
          },
          stime: BawApp.utc_tz.parse('Tue Oct 11 08:13:45 2022'),
          obittime: BawApp.utc_tz.parse('Tue Oct 11 08:13:47 2022'),
          jobdir: '/home/pbsuser',
          substate: 92,
          variable_list: {
            'PBS_O_HOME' => '/home/pbsuser',
            'PBS_O_LANG' => 'en_US.UTF-8',
            'PBS_O_LOGNAME' => 'pbsuser',
            'PBS_O_PATH' => '/home/pbsuser/bin:/usr/local/bin:/usr/bin:/bin:/opt/pbs/bin',
            'PBS_O_MAIL' => '/var/mail/pbsuser',
            'PBS_O_SHELL' => '/bin/bash',
            'PBS_O_WORKDIR' => '/home/pbsuser',
            'PBS_O_SYSTEM' => 'Linux',
            'PBS_O_QUEUE' => 'workq',
            'PBS_O_HOST' => '725ccdf1a5fb'
          },
          comment: 'Job run at Tue Oct 11 at 08:13 on (725ccdf1a5fb:ncpus=1) and finished',
          etime: BawApp.utc_tz.parse('Tue Oct 11 08:13:45 2022'),
          run_count: 1,
          stageout_status: 1,
          exit_status: 0,
          submit_arguments: '-N testname -',
          history_timestamp: Time.zone.at(1_665_476_027),
          project: '_pbs_project_default',
          submit_host: '725ccdf1a5fb',
          eligible_time: 130,
          array: true,
          array_state_count: 'Queued:999 Running:0 Exiting:0 Expired:2 ',
          array_indices_submitted: '0-1000',
          array_indices_remaining: '2-1000',
          estimated: {
            exec_vnode: '(cl4n017[0]:ncpus=8:mem=33554432kb)+(cl4n017[1]:ncpus=4)',
            start_time: 'Wed Oct 12 14:48:45 2022'
          }
        }
      }
    }
  }

  it 'transforms a job list' do
    t = PBS::Transformers::StatusTransformer.new
    result = t.call(raw)

    expect(result).to be_an_instance_of(PBS::Models::JobList)

    expect(result.to_h).to match(expected)
  end

  it 'gracefully handles an already decoded json payload' do
    t = PBS::Transformers::StatusTransformer.new
    result = t.call(JSON.parse(raw, PBS::Connection::JSON_PARSER_OPTIONS))

    expect(result).to be_an_instance_of(PBS::Models::JobList)

    expect(result.to_h).to match(expected)
  end
end
