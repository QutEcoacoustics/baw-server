# frozen_string_literal: true

describe AnalysisJobsItem do
  describe 'scopes: sample_for_queueable_across_jobs' do
    include SqlHelpers::Example

    let!(:job1) { create(:analysis_job) }
    let!(:job2) { create(:analysis_job) }
    let!(:job3) { create(:analysis_job) }

    before do
      AnalysisJobsItem.delete_all
      create(:analysis_jobs_item, analysis_job: job1, transition: AnalysisJobsItem::TRANSITION_QUEUE)
      create(:analysis_jobs_item, analysis_job: job1, transition: AnalysisJobsItem::TRANSITION_QUEUE)

      create(:analysis_jobs_item, analysis_job: job2, transition: AnalysisJobsItem::TRANSITION_QUEUE)
      create(:analysis_jobs_item, analysis_job: job2, transition: AnalysisJobsItem::TRANSITION_QUEUE)
      create(:analysis_jobs_item, analysis_job: job2, transition: AnalysisJobsItem::TRANSITION_QUEUE)
      create(:analysis_jobs_item, analysis_job: job2, transition: AnalysisJobsItem::TRANSITION_QUEUE)
      create(:analysis_jobs_item, analysis_job: job2, transition: AnalysisJobsItem::TRANSITION_QUEUE)
      create(:analysis_jobs_item, analysis_job: job2, transition: AnalysisJobsItem::TRANSITION_QUEUE)

      create(:analysis_jobs_item, analysis_job: job3, transition: AnalysisJobsItem::TRANSITION_QUEUE)
      create(:analysis_jobs_item, analysis_job: job3, transition: AnalysisJobsItem::TRANSITION_QUEUE)
      create(:analysis_jobs_item, analysis_job: job3, transition: AnalysisJobsItem::TRANSITION_QUEUE)
      create(:analysis_jobs_item, analysis_job: job3, transition: AnalysisJobsItem::TRANSITION_QUEUE)
    end

    it 'produces expected sql' do
      query = <<~SQL.squish
        WITH "groupings" AS (
        SELECT "analysis_jobs_items"."id", (row_number()
        OVER (PARTITION BY "analysis_jobs_items"."analysis_job_id" ORDER BY random()))
        AS "random_group"
        FROM "analysis_jobs_items"
        WHERE ("analysis_jobs_items"."transition" = 'queue')
        OR ("analysis_jobs_items"."transition" = 'retry')
        ORDER BY random_group LIMIT 10)
        SELECT "analysis_jobs_items".*
        FROM "analysis_jobs_items" INNER JOIN "groupings"
        ON "analysis_jobs_items"."id" = "groupings"."id"
        ORDER BY "groupings"."random_group"
      SQL

      comparison_sql(
        AnalysisJobsItem.sample_for_queueable_across_jobs(10).to_sql,
        query
      )
    end

    it 'can return all items' do
      items = AnalysisJobsItem.sample_for_queueable_across_jobs(1000).to_a
      expect(items.size).to be 12

      # there should be no duplicates
      expect(items.uniq(&:id).size).to be 12

      # the first three should have one sample from each job
      expect(items[0..2].map(&:analysis_job_id)).to contain_exactly(job1.id, job2.id, job3.id)

      # the same for the next three
      expect(items[3..5].map(&:analysis_job_id)).to contain_exactly(job1.id, job2.id, job3.id)

      # now we've run out of items from job1, so the next two should be from job2 and job3
      expect(items[6..7].map(&:analysis_job_id)).to contain_exactly(job2.id, job3.id)

      # and again
      expect(items[8..9].map(&:analysis_job_id)).to contain_exactly(job2.id, job3.id)

      # now we've run out of items from job3, so the rest should be from job2
      expect(items[10..11].map(&:analysis_job_id)).to contain_exactly(job2.id, job2.id)
    end

    it 'can return iterative subsets' do
      # same as above test but we pull back smaller batches, modify their status and then pull back more
      items = AnalysisJobsItem.sample_for_queueable_across_jobs(3).to_a
      expect(items.map(&:analysis_job_id)).to contain_exactly(job1.id, job2.id, job3.id)
      items.each { |item| item.update_column(:transition, nil) }

      items = AnalysisJobsItem.sample_for_queueable_across_jobs(3).to_a
      expect(items.map(&:analysis_job_id)).to contain_exactly(job1.id, job2.id, job3.id)
      items.each { |item| item.update_column(:transition, nil) }

      # we've run out of items from job1 now
      items = AnalysisJobsItem.sample_for_queueable_across_jobs(2).to_a
      expect(items.map(&:analysis_job_id)).to contain_exactly(job2.id, job3.id)
      items.each { |item| item.update_column(:transition, nil) }

      items = AnalysisJobsItem.sample_for_queueable_across_jobs(2).to_a
      expect(items.map(&:analysis_job_id)).to contain_exactly(job2.id, job3.id)
      items.each { |item| item.update_column(:transition, nil) }

      # we've run out of items from job3 now
      items = AnalysisJobsItem.sample_for_queueable_across_jobs(2).to_a
      expect(items.map(&:analysis_job_id)).to contain_exactly(job2.id, job2.id)
      items.each { |item| item.update_column(:transition, nil) }

      # nothing left
      items = AnalysisJobsItem.sample_for_queueable_across_jobs(100).to_a
      expect(items).to be_empty
    end
  end

  describe 'scopes: stale_across_jobs' do
    include Dry::Monads[:result]

    let!(:job1) { create(:analysis_job) }
    let!(:job2) { create(:analysis_job) }
    let!(:job3) { create(:analysis_job) }

    before do
      AnalysisJobsItem.delete_all

      AnalysisJobsItem.aasm.state_machine.config.no_direct_assignment = false

      half = 12.hours.ago
      full = 24.hours.ago

      [
        # job, status, transition, created_at
        [job1, :working, :finish, full],
        [job1, :working, nil, full],

        [job2, :working, nil, half],
        [job2, :working, :finish, half],
        [job2, :working, :cancel, half],
        [job2, :queued, nil, half],
        [job2, :queued, :finish, half],
        [job2, :queued, :cancel, half],
        [job2, :working, nil, full],
        [job2, :working, :finish, full],
        [job2, :working, :cancel, full],
        [job2, :queued, nil, full],
        [job2, :queued, :finish, full],
        [job2, :queued, :cancel, full],

        [job3, :working, nil, half],
        [job3, :working, :finish, half],
        [job3, :working, :cancel, half],
        [job3, :queued, nil, half],
        [job3, :queued, :finish, half],
        [job3, :queued, :cancel, half],
        [job3, :working, nil, full],
        [job3, :working, :finish, full],
        [job3, :working, :cancel, full],
        [job3, :queued, nil, full],
        [job3, :queued, :finish, full],
        [job3, :queued, :cancel, full]
      ].each_with_index do |data, index|
        analysis_job, status, transition, created_at = data
        Timecop.freeze(created_at)
        allow(BawWorkers::Config.batch_analysis).to receive(:submit_job).and_return(Success("iamanqueueid#{index}"))

        item = create(
          :analysis_jobs_item,
          analysis_job:,
          status: :new
        )

        item.queue if [:queued, :working].include?(status)
        item.work if status == :working

        item.transition = transition.to_s if transition.present?

        item.save!

        Timecop.return
      end

      AnalysisJobsItem.aasm.state_machine.config.no_direct_assignment = true
    end

    it 'find stale items' do
      results = AnalysisJobsItem.stale_across_jobs(100, stale_after: 1.day.ago)
      expect(results.count).to be 5

      expect(results.map(&:analysis_job_id)).to(
        contain_exactly(job1.id, job2.id, job2.id, job3.id, job3.id)
      )
    end

    it 'can find stale items with a configurable limit' do
      results = AnalysisJobsItem.stale_across_jobs(100, stale_after: 12.hours.ago)
      expect(results.count).to be 9

      expect(results.map(&:analysis_job_id)).to(
        contain_exactly(job1.id, job2.id, job2.id, job2.id, job2.id, job3.id, job3.id, job3.id, job3.id)
      )
    end

    it 'the limit will exclude items if set high' do
      results = AnalysisJobsItem.stale_across_jobs(100, stale_after: 3.days.ago)
      expect(results.count).to be 0
    end
  end
end
