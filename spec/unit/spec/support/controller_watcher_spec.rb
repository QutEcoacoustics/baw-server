# frozen_string_literal: true

describe ControllerWatcher, type: :request do
  prepare_users

  prepare_project

  watch_controller(ProjectsController)

  it 'processing a request records metrics' do
    expect(controller_invocation_count(ProjectsController, :index)).to eq(0)
    get '/projects/', **api_headers(owner_token)
    expect(controller_invocation_count(ProjectsController, :index)).to eq(1)
    get '/projects/', **api_headers(owner_token)
    expect(controller_invocation_count(ProjectsController, :index)).to eq(2)

    reset_controller_invocation_count(ProjectsController, :index)

    expect(controller_invocation_count(ProjectsController, :index)).to eq(0)
    get '/projects/', **api_headers(owner_token)
    expect(controller_invocation_count(ProjectsController, :index)).to eq(1)
  end

  context 'with namespaced controllers' do
    watch_controller(Internal::SftpgoController)

    let(:headers) {
      {
        'ACCEPT' => 'application/json',
        'CONTENT_TYPE' => 'application/json',
        'REMOTE_ADDR' => '172.0.0.1'
      }.freeze
    }

    let(:payload) {
      <<~JSON
        {"action":"download","username":"user","path":"/srv/sftpgo/data/user/test.R","virtual_path":"/test.R","fs_provider":0,"status":1,"protocol":"SFTP","ip":"172.18.0.1","session_id":"SFTP_e854785960bc21d240cd50b8f94c1452e185d5182aecd08f3b99a64d6876395a_1","timestamp":1649845689143321984}
      JSON
    }

    it 'works' do
      expect(controller_invocation_count(Internal::SftpgoController, :hook)).to eq(0)

      post '/internal/sftpgo/hook', params: payload, headers: headers

      expect(controller_invocation_count(Internal::SftpgoController, :hook)).to eq(1)

      exists = BawWorkers::Config.redis_communicator.redis.exists?(
        "#{ControllerWatcher::NAMESPACE}Internal::SftpgoController#hook"
      )
      expect(exists).to be true
    end
  end

  it 'can wait for invocations' do
    # set the count to non-zero
    get '/projects/', **api_headers(owner_token)

    Sync do |task|
      task.async do
        sleep 2
        get '/projects/', **api_headers(owner_token)
        sleep 0.5
        get '/projects/', **api_headers(owner_token)
        sleep 0.5
        get '/projects/', **api_headers(owner_token)
      end
      task.async do |_task|
        start = Time.now
        wait_for_action_invocation(ProjectsController, :index, goal: 4)

        stop = Time.now
        expect(stop - start).to be_within(0.25).of(3)
      end
    end

    expect(controller_invocation_count(ProjectsController, :index)).to eq(4)
  end

  context 'it resets counts between specs (relies on redis database cleaner)' do
    it 'processing a request records metrics' do
      expect(controller_invocation_count(ProjectsController, :index)).to eq(0)
      get '/projects/', **api_headers(owner_token)
      expect(controller_invocation_count(ProjectsController, :index)).to eq(1)
      get '/projects/', **api_headers(owner_token)
      expect(controller_invocation_count(ProjectsController, :index)).to eq(2)
    end

    it 'processing a request records metrics (2)' do
      expect(controller_invocation_count(ProjectsController, :index)).to eq(0)
      get '/projects/', **api_headers(owner_token)
      expect(controller_invocation_count(ProjectsController, :index)).to eq(1)
      get '/projects/', **api_headers(owner_token)
      expect(controller_invocation_count(ProjectsController, :index)).to eq(2)
    end
  end
end
