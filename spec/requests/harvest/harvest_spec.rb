# frozen_string_literal: true

require_relative 'harvest_spec_common'

describe 'Harvesting files' do
  include HarvestSpecCommon

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
end
