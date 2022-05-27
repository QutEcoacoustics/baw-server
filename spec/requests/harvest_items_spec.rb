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
    expect(api_data).to match([
      a_hash_including(
        id: nil,
        path: 'a'
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
    ])
  end

  it 'can query for harvest items (sub directory)' do
    get "/projects/#{project.id}/harvests/#{harvest.id}/items/a/b", **api_headers(owner_token)

    expect_success
    expect(api_data).to match([
      a_hash_including(
        id: nil,
        path: 'a/b/c'
      ),
      a_hash_including(
        id: nil,
        path: 'a/b/d'
      ),
      a_hash_including(
        id: @hi7.id,
        path: @hi7.path_relative_to_harvest
      ),
      a_hash_including(
        id: @hi8.id,
        path: @hi8.path_relative_to_harvest
      )
    ])
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
    expect(api_data).to match(matchers)
  end

  def create_with_validations(fixable: 0, not_fixable: 0, sub_directories: nil)
    validations = []
    fixable.times do
      validations << ::BawWorkers::Jobs::Harvest::ValidationResult.new(
        status: :fixable,
        name: :wascally_wabbit,
        message: nil
      )
    end
    not_fixable.times do
      validations << ::BawWorkers::Jobs::Harvest::ValidationResult.new(
        status: :not_fixable,
        name: :kiww_the_wabbit,
        message: nil
      )
    end

    info = ::BawWorkers::Jobs::Harvest::Info.new(
      validations:
    )

    path = generate_recording_name(Time.now)
    path = File.join(*[harvest.upload_directory_name, sub_directories, path].compact)

    create(:harvest_item, path:, status: HarvestItem::STATUS_METADATA_GATHERED, info:, harvest:)
  end
end
