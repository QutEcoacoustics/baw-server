# frozen_string_literal: true

require_relative 'harvest_spec_common'

describe 'Harvesting a batch of files' do
  include HarvestSpecCommon

  extend WebServerHelper::ExampleGroup

  context 'when enqueuing the entire set of files', :clean_by_truncation, :slow, web_server_timeout: 60 do
    expose_app_as_web_server

    pause_all_jobs
    ignore_pending_jobs

    let(:duplicates) { 1000 }

    before do
      create_harvest(streaming: false)
      expect_success

      # upload a sample file
      name = generate_recording_name(Time.new(2020, 1, 1, 0, 0, 0, '+00:00'), extension: '.ogg')
      upload_file(connection, Fixtures.audio_file_mono, to: "/#{site.unique_safe_name}/#{name}")

      transition_harvest(:scanning)
      expect_success

      # harvest job followed by scan job
      perform_jobs(count: 2)
      expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::ScanJob)

      get_harvest
      expect(harvest).to be_metadata_review

      # now duplicate the rows to simulate a really large harvest!
      duplicate_rows

      expect(harvest.harvest_items.count).to eq(duplicates + 1)
    end

    it 'performs well on the :metadata_review->:metadata_extraction transition' do
      # the previous harvest job's status will deleted when it is reenqueued which
      # messes up our accounting and results in this wait never finishing.
      BawWorkers::ResqueApi.statuses_clear

      # before the changes associated with this benchmark the following request
      # took ≈ 11 seconds
      expect {
        transition_harvest(:metadata_extraction)
      }.to perform_under(0.5).sec.warmup(0)

      expect_success

      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::ReenqueueJob)
      expect_enqueued_jobs(1)
      perform_jobs(count: 1)

      expect_enqueued_jobs(duplicates + 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
    end

    it 'performs well on the :metadata_review->:processing transition' do
      # before the changes associated with this benchmark the following request
      # took ≈ 11.5 seconds
      expect {
        transition_harvest(:processing)
      }.to perform_under(0.5).sec.warmup(0)

      expect_success

      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::ReenqueueJob)
      expect_enqueued_jobs(1)
      perform_jobs(count: 1)

      expect_enqueued_jobs(duplicates + 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
    end

    def duplicate_rows
      columns = (HarvestItem.column_names - ['id']).join(', ')

      duplicate_rows_query = <<~SQL
        INSERT INTO harvest_items (#{columns})
        (
          SELECT  #{columns}
          FROM  (
            SELECT #{columns} FROM harvest_items ORDER BY id DESC LIMIT 1
          ) AS t
          CROSS JOIN LATERAL generate_series(1,#{duplicates})
        )
      SQL
      ActiveRecord::Base.connection.execute(duplicate_rows_query)
    end
  end
end
