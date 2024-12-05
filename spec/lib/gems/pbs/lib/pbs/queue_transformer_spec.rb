# frozen_string_literal: true

describe PBS::Transformers::QueueTransformer do
  let(:raw) {
    <<~JSON
      {
        "timestamp":1666251726,
        "pbs_version":"2021.1.3.20220217134230",
        "pbs_server":"pbs-primary",
        "Queue": {
          "quick":{
            "queue_type":"Execution",
            "Priority":25,
            "total_jobs":7,
            "state_count":"Transit:0 Queued:5 Held:0 Waiting:0 Running:2 Exiting:0 Begun:0 ",
            "from_route_only":"True",
            "resources_max":{
                "ngpus":0,
                "walltime":"04:00:00"
            },
            "resources_min":{
              "ngpus":1
            },
            "resources_assigned":{
                "mem":"132gb",
                "mpiprocs":0,
                "ncpus":5,
                "nodect":2
            },
            "max_run":"[o:PBS_ALL=5000]",
            "max_run_res":{
                "mem":"[u:PBS_GENERIC=40tb]",
                "ncpus":"[u:PBS_GENERIC=5000]"
            },
            "enabled":"True",
            "started":"True",
            "queued_jobs_threshold":"[u:PBS_GENERIC=5000]"
          }
        }
      }
    JSON
  }

  let(:expected) {
    {
      timestamp: Time.zone.at(1_666_251_726),
      pbs_version: '2021.1.3.20220217134230',
      pbs_server: 'pbs-primary',
      queue: {
        'quick' => {
          queue_type: 'Execution',
          priority: 25,
          total_jobs: 7,
          state_count: 'Transit:0 Queued:5 Held:0 Waiting:0 Running:2 Exiting:0 Begun:0 ',
          from_route_only: true,
          resources_max: {
            ngpus: 0,
            walltime: '04:00:00'
          },
          resources_min: {
            ngpus: 1
          },
          resources_assigned: {
            mem: '132gb',
            mpiprocs: 0,
            ncpus: 5,
            nodect: 2
          },
          max_run: '[o:PBS_ALL=5000]',
          max_run_res: {
            mem: '[u:PBS_GENERIC=40tb]',
            ncpus: '[u:PBS_GENERIC=5000]'
          },
          enabled: true,
          started: true,
          queued_jobs_threshold: '[u:PBS_GENERIC=5000]'
        }
      }
    }
  }

  it 'transforms a queue list' do
    t = PBS::Transformers::QueueTransformer.new
    result = t.call(raw)

    expect(result).to be_an_instance_of(PBS::Models::QueueList)

    expect(result.to_h).to match(expected)
  end
end
