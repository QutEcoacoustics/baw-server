# frozen_string_literal: true

describe 'HarvestJob', :clean_by_truncation do
  include_context 'shared_test_helpers'

  prepare_users
  prepare_project
  prepare_region
  prepare_site

  prepare_harvest_with_mappings do
    [
      BawWorkers::Jobs::Harvest::Mapping.new(
        path: '',
        site_id: site.id,
        utc_offset: nil,
        recursive: false
      )
    ]
  end

  before do
    clear_original_audio
    clear_harvester_to_do
  end

  # fixes https://github.com/QutEcoacoustics/baw-server/issues/861
  it 'marks the item as failed if the file goes missing after metadata fixes' do
    paths = copy_fixture_to_harvest_directory(
      Fixtures.audio_file_mono,
      harvest,
      target_name: 'audio.wav'
    )

    harvest_item = HarvestItem.create!(
      harvest_id: harvest.id,
      status: HarvestItem::STATUS_NEW,
      uploader_id: harvest.creator.id,
      info: {},
      path: paths.harvester_relative_path
    )

    job = BawWorkers::Jobs::Harvest::HarvestJob.new
    allow(Emu).to receive(:execute).and_wrap_original do |m, *args|
      # delete the file just before metadata extraction
      harvest_item.absolute_path.delete if args.first == 'metadata'
      m.call(*args)
    end

    job.perform(harvest_item.id, should_harvest: true)

    item = HarvestItem.first
    aggregate_failures do
      expect(item).to be_failed
      expect(item.info.to_h[:validations]).to eq [
        {
          name: :does_not_exist,
          status: :not_fixable,
          message: "File #{harvest_item.absolute_path} does not exist"
        }
      ]
    end
  end
end
