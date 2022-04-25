# frozen_string_literal: true

describe BawWorkers::Jobs::Harvest::Action do
  require 'support/shared_test_helpers'

  include_context 'shared_test_helpers'

  let(:queue_name) { Settings.actions.harvest.queue }
  # let(:folder_example) { File.expand_path File.join(File.dirname(__FILE__), 'folder_example.yml') }
  # let(:test_harvest_request_params) {
  #   {
  #     file_path: '/path1/path2/TEST_20140731_100956.wav',
  #     file_name: 'TEST_20140731_100956.wav',
  #     extension: 'wav',
  #     access_time: '2014-12-02T19:41:55.862+00:00',
  #     change_time: '2014-12-02T19:41:55.906+00:00',
  #     modified_time: '2014-12-02T19:41:55.906+00:00',
  #     data_length_bytes: 498_220,
  #     project_id: 1020,
  #     site_id: 1109,
  #     uploader_id: 138,
  #     utc_offset: '+10',
  #     raw: {
  #       prefix: 'TEST_',
  #       year: '2014',
  #       month: '07',
  #       day: '31',
  #       hour: '10',
  #       min: '09',
  #       sec: '56',
  #       ext: 'wav'
  #     },
  #     recorded_date: '2014-07-31T10:09:56.000+10:00',
  #     prefix: 'TEST'
  #   }
  # }
  # let(:expected_payload) {
  #   [
  #     { 'harvest_params' => test_harvest_request_params.stringify_keys }
  #   ]
  # }

  before do
    clear_harvester_to_do
  end

  pause_all_jobs

  it 'works on the harvest queue' do
    expect((BawWorkers::Jobs::Harvest::Action.queue_name)).to eq(queue_name)
  end

  it 'can enqueue' do
    item = create(:harvest_item)
    job = BawWorkers::Jobs::Harvest::Action.perform_later!(item.id, item.path)
    expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::Action)

    clear_pending_jobs
  end

  it 'has a sensible name' do
    item = create(:harvest_item)

    job = BawWorkers::Jobs::Harvest::Action.new(item.id, item.path)

    expected = "HarvestItem(#{item.id}) for: #{item.path}"
    expect(job.name).to eq(expected)
  end
end
