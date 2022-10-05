# frozen_string_literal: true

require_relative 'harvest_spec_common'

describe 'Harvesting files' do
  include HarvestSpecCommon
  render_error_responses

  it 'will not allow a harvest to be created if the project does not allow uploads' do
    project.allow_audio_upload = false
    project.save!

    create_harvest

    expect_error(
      :unprocessable_entity,
      'Record could not be saved',
      { project: ['A harvest cannot be created unless its parent project has enabled audio upload'] }
    )
  end

  it 'will not create the harvest if there is a problem contacting the upload service' do
    stub_request(:post, 'upload.test:8080/api/v2/users')
      .to_return(
        body: '{"message":"cannot stat dir", "error": "error message"}',
        status: 500,
        headers: { content_type: 'application/json' }
      )

    create_harvest

    expect_error(
      :internal_server_error,
      'Upload service failure: Failed to create_upload_user, got 500'
    )

    # don't leave a straggler
    expect(Harvest.count).to eq 0
  end

  it 'abort works with a malformed upload' do
    h = Harvest.new(project_id: project.id, creator: owner_user)
    h.save!

    self.harvest_id = h.id

    get_harvest

    # represents some kind of failed creation request
    expect(harvest).to be_new_harvest
    expect(harvest.upload_user).to be_blank

    transition_harvest(:complete)
    expect_success

    expect(harvest).to be_complete
  end

  # This shouldn't be needed yet... wait and see
  # context 'will attempt to rectify issues with the upload slot if present' do
  #   before
  #     create_harvest
  #   end
  #
  #   it 'opens the connection if it is closed when it should be open' do
  #     harvest.close_upload_slot
  #     get_harvest
  #   end
  #
  #   it 'enables the connection when it should be enabled' do
  #   end
  #
  #   it 'disables the connection when it should be disabled' do
  #   end
  #
  #   it 'closes the connection when it should be closed' do
  #   end
  # end

  context 'with incorrect project_id in route parameters' do
    let!(:another_project) {
      Creation::Common.create_project(owner_user)
    }

    it 'will error if it is different in the route and body during creation' do
      body = {
        harvest: {
          streaming: false,
          project_id: project.id
        }
      }

      post "/projects/#{another_project.id}/harvests", params: body, **api_with_body_headers(owner_token)

      expect_error(
        :not_found,
        'Could not find the requested page: project_id in route does not match the harvest\'s project_id',
        {
          original_route: "/projects/#{another_project.id}/harvests",
          original_http_method: 'POST'
        }
      )
    end

    it 'will error if it is different in the route and the existing project during update' do
      create_harvest
      expect_success

      body = {
        harvest: {
          status: :scanning
        }
      }

      patch "/projects/#{another_project.id}/harvests/#{harvest.id}", params: body, **api_with_body_headers(owner_token)

      expect_error(
        :not_found,
        'Could not find the requested page: project_id in route does not match the harvest\'s project_id',
        {
          original_route: "/projects/#{another_project.id}/harvests/#{harvest.id}",
          original_http_method: 'PATCH'
        }
      )
    end

    it 'will error if it is different than the harvest\'s project_id' do
      create_harvest
      expect_success

      get "/projects/#{another_project.id}/harvests/#{harvest.id}", **api_headers(owner_token)

      expect_error(
        :not_found,
        'Could not find the requested page: project_id in route does not match the harvest\'s project_id',
        {
          original_route: "/projects/#{another_project.id}/harvests/#{harvest.id}",
          original_http_method: 'GET'
        }
      )
    end

    it 'will error with 404 if it does not exist' do
      create_harvest
      expect_success

      get "/projects/999/harvests/#{harvest.id}", **api_headers(owner_token)

      expect_error(:not_found, 'Could not find the requested item.')
    end
  end

  context 'mappings' do
    let(:another_site) {
      Creation::Common.create_site(owner_user, project, region:)
    }

    before do
      create_harvest(streaming: false)
      expect_success
    end

    it 'can add new mappings' do
      add_mapping(BawWorkers::Jobs::Harvest::Mapping.new(
        site_id: another_site.id,
        path: '',
        utc_offset: '-04:00',
        recursive: true
      ))

      expect(harvest.mappings).to match(a_collection_containing_exactly(
        a_hash_including(
          site_id: site.id,
          path: site.unique_safe_name,
          utc_offset: nil,
          recursive: true
        ),
        a_hash_including(
          site_id: another_site.id,
          path: '',
          utc_offset: '-04:00',
          recursive: true
        )
      ))
    end

    it 'can empty mappings' do
      body = {
        harvest: {
          mappings: []
        }
      }

      patch "/projects/#{project.id}/harvests/#{harvest.id}", params: body, **api_with_body_headers(owner_token)

      harvest.reload

      expect(harvest.mappings).to match([])
    end

    it 'rejects mappings with invalid site ids' do
      add_mapping(BawWorkers::Jobs::Harvest::Mapping.new(
        site_id: 123_456,
        path: '',
        utc_offset: '-04:00',
        recursive: true
      ))

      expect_error(:unprocessable_entity, /Record could not be saved/, {
        mappings: [
          "Site '123456' does not exist for mapping ''"
        ]
      })
    end

    it 'rejects mappings with an invalid path' do
      add_mapping({
        site_id: nil,
        path: nil,
        utc_offset: '-04:00',
        recursive: true
      })

      expect_error(:unprocessable_entity, /Invalid mapping.*nil \(NilClass\) has invalid type for :path/)
    end

    it 'rejects mappings with duplicate paths' do
      add_mapping(BawWorkers::Jobs::Harvest::Mapping.new(
        site_id: nil,
        path: '',
        utc_offset: '-04:00',
        recursive: true
      ))

      expect_success

      add_mapping(BawWorkers::Jobs::Harvest::Mapping.new(
        site_id: nil,
        path: '',
        utc_offset: '-04:00',
        recursive: true
      ))

      expect_error(:unprocessable_entity, /Record could not be saved/, {
        mappings: [
          "Duplicate path in mappings: ''"
        ]
      })
    end

    it 'rejects mappings with duplicate paths (sub-directory)' do
      add_mapping(BawWorkers::Jobs::Harvest::Mapping.new(
        site_id: nil,
        path: '/abc',
        utc_offset: '-04:00',
        recursive: true
      ))

      expect_success

      add_mapping(BawWorkers::Jobs::Harvest::Mapping.new(
        site_id: nil,
        path: 'abc',
        utc_offset: '-04:00',
        recursive: true
      ))

      expect_error(:unprocessable_entity, /Record could not be saved/, {
        mappings: [
          "Duplicate path in mappings: 'abc'"
        ]
      })
    end

    it 'rejects malformed mappings (missing path)' do
      add_mapping({
        site_id: 123_456,
        utc_offset: '-04:00',
        recursive: true
      })

      expect_error(:unprocessable_entity, /Invalid mapping.*path is missing/)
    end

    it 'rejects malformed mappings (extra field)' do
      add_mapping({
        path: '',
        banana: 'banana',
        site_id: 123_456,
        utc_offset: '-04:00',
        recursive: true
      })

      expect_error(:unprocessable_entity, /found unpermitted parameter: :banana/)
    end
  end

  describe 'ignores WinSCP .filepart files', :clean_by_truncation, :slow, web_server_timeout: 60 do
    extend WebServerHelper::ExampleGroup

    expose_app_as_web_server
    pause_all_jobs

    before do
      create_harvest(streaming: false)
      expect_success
    end

    it 'ignores .filepart upload events' do
      upload_file(connection, Fixtures.audio_file_mono, to: '/20190913T000000+1000_REC.flac.filepart')

      wait_for_webhook

      expect(HarvestItem.count).to eq 0
      expect_enqueued_jobs(0)
      clear_pending_jobs
    end

    it 'can enqueue a harvest job on a .filepart rename' do
      upload_file(connection, Fixtures.audio_file_mono, to: '/20190913T000000+1000_REC.flac.filepart')

      wait_for_webhook(goal: 1)

      expect(HarvestItem.count).to eq 0
      expect_enqueued_jobs(0)

      rename_remote_file(
        connection,
        from: '/20190913T000000+1000_REC.flac.filepart',
        to: '/20190913T000000+1000_REC.flac'
      )

      wait_for_webhook(goal: 2)

      expect(HarvestItem.count).to eq 1
      # @type [HarvestItem]
      first = HarvestItem.first
      expect(first.path).to eq "harvest_#{harvest.id}/20190913T000000+1000_REC.flac"
      expect(first.status).to eq HarvestItem::STATUS_NEW
      expect(first.absolute_path.exist?).to be true

      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      clear_pending_jobs
    end
  end

  describe 'for System Volume Information directories', :clean_by_truncation, :slow, web_server_timeout: 60 do
    extend WebServerHelper::ExampleGroup

    expose_app_as_web_server
    pause_all_jobs

    before do
      create_harvest(streaming: false)
      expect_success
    end

    it 'ignores them' do
      upload_file(connection, Fixtures.audio_file_mono,
        to: '/a/System Volume Information/20190913T000000+1000_REC.flac')

      wait_for_webhook

      expect(HarvestItem.count).to eq 0
      expect_enqueued_jobs(0)
      clear_pending_jobs
    end
  end
end
