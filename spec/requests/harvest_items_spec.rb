# frozen_string_literal: true

describe 'Harvest items info' do
  prepare_users
  prepare_project
  prepare_region
  prepare_site
  prepare_harvest

  before do
    @hi1 = create_with_validations(fixable: 3, not_fixable: 1)
    @hi2 = create_with_validations(fixable: 0, not_fixable: 1)
    @hi3 = create_with_validations(fixable: 1, not_fixable: 0)
    @hi4 = create_with_validations(fixable: 0, not_fixable: 1, sub_directories: 'a/b/c')
    @hi5 = create_with_validations(fixable: 0, not_fixable: 0, sub_directories: 'a/b/c')
    @hi6 = create_with_validations(fixable: 0, not_fixable: 0, sub_directories: 'a/b/d')
    @hi7 = create_with_validations(fixable: 1, not_fixable: 0, sub_directories: 'a/b')
    @hi8 = create_with_validations(fixable: 1, not_fixable: 0, sub_directories: 'a/b')
    @hi9 = create_with_validations(fixable: 1, not_fixable: 0, sub_directories: 'z/b')
  end

  it 'can query for harvest items (root path)' do
    get "/projects/#{project.id}/harvests/#{harvest.id}/items", **api_headers(owner_token)

    expect_success
    expect(api_data).to match(a_collection_containing_exactly(
      a_hash_including(
        id: nil,
        path: 'a',
        report: a_hash_including(
          items_total: 5,
          items_invalid_fixable: 2,
          items_invalid_not_fixable: 1
        )
      ),
      a_hash_including(
        id: nil,
        path: 'z',
        report: a_hash_including(
          items_total: 1,
          items_invalid_fixable: 1,
          items_invalid_not_fixable: 0
        )
      ),
      a_hash_including(
        id: @hi1.id,
        path: @hi1.path_relative_to_harvest
      ),
      a_hash_including(
        id: @hi2.id,
        path: @hi2.path_relative_to_harvest
      ),
      a_hash_including(
        id: @hi3.id,
        path: @hi3.path_relative_to_harvest
      )
    ))

    expect_has_paging(page: 1, total: 5)
  end

  it 'can query for harvest items (sub directory)' do
    get "/projects/#{project.id}/harvests/#{harvest.id}/items/a/b", **api_headers(owner_token)

    expect_success
    expect(api_data).to match(a_collection_containing_exactly(
      a_hash_including(
        id: nil,
        path: 'a/b/c',
        report: a_hash_including(
          items_total: 2,
          items_invalid_fixable: 0,
          items_invalid_not_fixable: 1
        )
      ),
      a_hash_including(
        id: nil,
        path: 'a/b/d',
        report: a_hash_including(
          items_total: 1,
          items_invalid_fixable: 0,
          items_invalid_not_fixable: 0
        )
      ),
      a_hash_including(
        id: @hi7.id,
        path: @hi7.path_relative_to_harvest
      ),
      a_hash_including(
        id: @hi8.id,
        path: @hi8.path_relative_to_harvest
      )
    ))

    expect_has_paging(page: 1, total: 4)
  end

  it 'can also do plain old filter requests' do
    get "/projects/#{project.id}/harvests/#{harvest.id}/items/filter", **api_headers(owner_token)

    expect_success

    matchers = (1..9).map { |index|
      a_hash_including(
        id: instance_variable_get("@hi#{index}").id,
        path: instance_variable_get("@hi#{index}").path_relative_to_harvest
      )
    }
    expect(api_data).to match(a_collection_containing_exactly(*matchers))

    expect_has_paging(page: 1, total: 9)
  end

  context 'when generating CSV reports via filter' do
    before do
      Timecop.freeze(Time.utc(2022, 1, 2, 3, 4, 5.678))
    end

    after do
      Timecop.return
    end

    it 'works with filter' do
      body = {
        projection: { include: [:id, :harvest_id, :path, :status, :audio_recording_id] },
        filter: {}
      }

      post "/projects/#{project.id}/harvests/#{harvest.id}/items/filter.csv?disable_paging=true",
        params: body,
        **api_with_body_headers(owner_token, accept: 'text/csv')

      expect_success
      expect(response.headers['Content-Type']).to eq('text/csv; charset=utf-8')
      expect(response.headers['Content-Disposition'])
        .to eq('attachment; filename="20220102T030405Z_harvest_items.csv"')

      results = CSV.parse(response_body, headers: true)
      expect(results.size).to eq(AudioRecording.count)

      expect(results.headers).to eq ['id', 'harvest_id', 'path', 'status', 'audio_recording_id']
      rows = results.map(&:to_h)
      HarvestItem.all.each { |item|
        expect(rows).to include(a_hash_including(
          'id' => item.id.to_s,
          'harvest_id' => item.harvest_id.to_s,
          'path' => item.path_relative_to_harvest,
          'status' => item.status,
          'audio_recording_id' => item.audio_recording_id.to_s
        ))
      }
    end
  end

  context 'with lots of items' do
    before do
      50.times do
        create_with_validations(fixable: 1, not_fixable: 0, sub_directories: 'a')

        create_with_validations(fixable: 0, not_fixable: 0, sub_directories: 'e')
      end
    end

    it 'can query for harvest items (root path)' do
      get "/projects/#{project.id}/harvests/#{harvest.id}/items", **api_headers(owner_token)

      expect_success
      expect(api_data).to match(a_collection_containing_exactly(
        a_hash_including(
          id: nil,
          path: 'a'
        ),
        a_hash_including(
          id: nil,
          path: 'e'
        ),
        a_hash_including(
          id: nil,
          path: 'z'
        ),
        a_hash_including(
          id: @hi1.id,
          path: @hi1.path_relative_to_harvest
        ),
        a_hash_including(
          id: @hi2.id,
          path: @hi2.path_relative_to_harvest
        ),
        a_hash_including(
          id: @hi3.id,
          path: @hi3.path_relative_to_harvest
        )
      ))

      expect_has_paging(page: 1, total: 6)
    end

    it 'can query for harvest items (sub directory)' do
      get "/projects/#{project.id}/harvests/#{harvest.id}/items/a", **api_headers(owner_token)

      expect_success
      expect(api_data).to include(a_hash_including(
        id: nil,
        path: 'a/b'
      ))
      expect(api_data.length).to eq 25

      expect_has_paging(page: 1, total: 50 + 1)
    end

    it 'can query for harvest items (sub directory, next page)' do
      get "/projects/#{project.id}/harvests/#{harvest.id}/items/a?page=2", **api_headers(owner_token)

      expect_success
      expect(api_data).not_to include(a_hash_including(
        id: nil,
        path: 'a/b'
      ))
      expect(api_data.length).to eq 25

      expect_has_paging(page: 2, total: 50 + 1)
    end

    it 'can query for harvest items (sub directory, last page)' do
      get "/projects/#{project.id}/harvests/#{harvest.id}/items/a?page=3", **api_headers(owner_token)

      expect_success
      expect(api_data).not_to include(a_hash_including(
        id: nil,
        path: 'a/b'
      ))
      expect(api_data.length).to eq 1

      expect_has_paging(page: 3, total: 50 + 1)
    end

    it 'can query for harvest items (the other sub directory)' do
      get "/projects/#{project.id}/harvests/#{harvest.id}/items/e", **api_headers(owner_token)

      expect_success
      expect(api_data).not_to match(a_hash_including(
        id: nil
      ))
      expect(api_data.length).to eq 25

      expect_has_paging(page: 1, total: 50)
    end
  end

  def create_with_validations(fixable: 0, not_fixable: 0, sub_directories: nil)
    validations = []
    fixable.times do
      validations << BawWorkers::Jobs::Harvest::ValidationResult.new(
        status: :fixable,
        name: :wascally_wabbit,
        message: nil
      )
    end
    not_fixable.times do
      validations << BawWorkers::Jobs::Harvest::ValidationResult.new(
        status: :not_fixable,
        name: :kiww_the_wabbit,
        message: nil
      )
    end

    info = BawWorkers::Jobs::Harvest::Info.new(
      validations:
    )

    path = generate_recording_name(Time.zone.now)
    path = File.join(*[harvest.upload_directory_name, sub_directories, path].compact)

    create(:harvest_item, path:, status: HarvestItem::STATUS_METADATA_GATHERED, info:, harvest:)
  end
end
