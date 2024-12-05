# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_jobs
#
#  id                                                                                                                                                                                      :integer          not null, primary key
#  amend_count(Count of amendments)                                                                                                                                                        :integer          default(0), not null
#  deleted_at                                                                                                                                                                              :datetime
#  description                                                                                                                                                                             :text
#  filter(API filter to include recordings in this job. If blank then all recordings are included.)                                                                                        :jsonb
#  name                                                                                                                                                                                    :string           not null
#  ongoing(If true the filter for this job will be evaluated after a harvest. If more items are found the job will move to the processing stage if needed and process the new recordings.) :boolean          default(FALSE), not null
#  overall_count                                                                                                                                                                           :integer          not null
#  overall_data_length_bytes                                                                                                                                                               :bigint           default(0), not null
#  overall_duration_seconds                                                                                                                                                                :decimal(14, 4)   not null
#  overall_status                                                                                                                                                                          :string           not null
#  overall_status_modified_at                                                                                                                                                              :datetime         not null
#  resume_count(Count of resumptions)                                                                                                                                                      :integer          default(0), not null
#  retry_count(Count of retries)                                                                                                                                                           :integer          default(0), not null
#  started_at                                                                                                                                                                              :datetime
#  suspend_count(Count of suspensions)                                                                                                                                                     :integer          default(0), not null
#  system_job(If true this job is automatically run and not associated with a single project. We can have multiple system jobs.)                                                           :boolean          default(FALSE), not null
#  created_at                                                                                                                                                                              :datetime
#  updated_at                                                                                                                                                                              :datetime
#  creator_id                                                                                                                                                                              :integer          not null
#  deleter_id                                                                                                                                                                              :integer
#  project_id(Project this job is associated with. This field simply influences which jobs are shown on a project page.)                                                                   :integer
#  updater_id                                                                                                                                                                              :integer
#
# Indexes
#
#  analysis_jobs_name_uidx            (name,creator_id) UNIQUE
#  index_analysis_jobs_on_creator_id  (creator_id)
#  index_analysis_jobs_on_deleter_id  (deleter_id)
#  index_analysis_jobs_on_project_id  (project_id)
#  index_analysis_jobs_on_updater_id  (updater_id)
#
# Foreign Keys
#
#  analysis_jobs_creator_id_fk  (creator_id => users.id)
#  analysis_jobs_deleter_id_fk  (deleter_id => users.id)
#  analysis_jobs_updater_id_fk  (updater_id => users.id)
#  fk_rails_...                 (project_id => projects.id) ON DELETE => cascade
#
require 'support/resque_helpers'
require 'aasm/rspec'

describe AnalysisJob do
  it 'has a valid factory' do
    job = build(:analysis_job)
    expect(job).to be_valid

    expect(create(:analysis_job)).to be_valid
  end
  #it {should have_many(:analysis_items)}

  it { is_expected.to belong_to(:creator) }
  it { is_expected.to belong_to(:updater).optional }
  it { is_expected.to belong_to(:deleter).optional }

  it { is_expected.to validate_presence_of(:name) }

  it 'is invalid without a name' do
    expect(build(:analysis_job, name: nil)).not_to be_valid
  end

  it 'ensures the name is no more than 255 characters' do
    test_string = 'a' * 256
    expect(build(:analysis_job, name: test_string)).not_to be_valid
    expect(build(:analysis_job, name: test_string[0..-2])).to be_valid
  end

  it 'ensures name is unique (case-insensitive) per user' do
    creator = create(:user)
    create(:analysis_job, name: 'There ain\'t room enough in this town for two of us sonny!', creator:)
    aj2 = build(:analysis_job, name: 'THERE AIN\'T ROOM ENOUGH IN THIS TOWN FOR TWO OF US SONNY!', creator:)

    expect(aj2).not_to be_valid
    expect(aj2.errors[:name].size).to eq(1)
  end

  it 'fails validation when scripts are empty' do
    test_item = build(:analysis_job)
    test_item.analysis_jobs_scripts = []

    expect(subject).not_to be_valid
    expect(subject.errors[:analysis_jobs_scripts]).to have(1).items
    expect(subject.errors[:analysis_jobs_scripts]).to eq ["can't be blank"]
  end

  # elsewhere we test the permissions for setting system_job or not
  # here we just test that the validation works
  describe 'system job and project id exclusion' do
    let(:project) { create(:project) }
    let(:analysis_job) { build(:analysis_job) }

    it 'validates that a non-system job with project_id must be valid' do
      analysis_job.system_job = false
      analysis_job.project_id = project.id

      expect(analysis_job).to be_valid
    end

    it 'validates that a system job without project_id must be valid' do
      analysis_job.system_job = true
      analysis_job.project_id = nil

      expect(analysis_job).to be_valid
    end

    it 'validates that a system job with project_id must be invalid' do
      analysis_job.system_job = true
      analysis_job.project_id = project.id

      expect(analysis_job).not_to be_valid
      expect(analysis_job.errors[:project_id].size).to eq(1)
      expect(analysis_job.errors[:project_id]).to eq ['must be blank for system jobs']
    end

    it 'validates that a non-system job without project_id must be invalid' do
      analysis_job.project_id = nil
      analysis_job.system_job = false

      expect(analysis_job).not_to be_valid
      expect(analysis_job.errors[:system_job].size).to eq(1)
      expect(analysis_job.errors[:system_job]).to eq ['must be true if project_id is blank']
    end
  end

  describe 'filter_as_relation' do
    include SqlHelpers::Example
    create_audio_recordings_hierarchy

    before do
      create_list(:audio_recording, 2, duration_seconds: 10, site:)
      create_list(:audio_recording, 3, duration_seconds: 300, site:)
      create_list(:audio_recording, 4, duration_seconds: 3600, site:)

      # there are a total of 10 recordings - the nine above and the default one
      # created by create_audio_recordings_hierarchy
    end

    let(:analysis_job) {
      create(:analysis_job, creator: writer_user, project:)
    }

    let(:permissions_sql) {
      Access::ByPermission
        .audio_recordings(
          analysis_job.creator,
          levels: Access::Permission::WRITER_OR_ABOVE,
          project_ids: analysis_job.project_id.nil? ? nil : [analysis_job.project_id]
        )
        .to_sql
        # we don't need the projection part of the query since that gets modified
        # by the Filter::Query
        .sub('SELECT "audio_recordings".* FROM "audio_recordings"', '')
    }

    it 'returns a AudioRecording::ActiveRecord_Relation object' do
      relation = analysis_job.filter_as_relation

      expect(relation.class.ancestors.include?(ActiveRecord::Relation)).to be true
    end

    it 'validates filter is a hash' do
      analysis_job.filter = 'not a hash'
      expect(analysis_job).not_to be_valid

      expect(analysis_job.errors[:filter]).to eq ['must be a hash']
    end

    [:filter, :projection, :sorting, :paging].each do |outer_key|
      it "validates #{outer_key} is not allowed" do
        analysis_job.filter = { outer_key => 'not allowed' }
        expect(analysis_job).not_to be_valid
        expect(analysis_job.errors[:filter]).to eq [
          'must be an inner filter, cannot contain any of filter, projection, paging, sorting'
        ]
      end
    end

    it 'executes the filter on validation to ensure it is valid' do
      # intentionally invalid
      analysis_job.filter = { duration_seconds_time: { gteq: 300 } }

      expect(analysis_job).not_to be_valid
      expect(analysis_job.errors[:filter].size).to eq(1)
      expect(analysis_job.errors[:filter]).to eq([
        'Filter parameters were not valid: Unrecognized combiner or field name `duration_seconds_time`.'
      ])
    end

    describe 'implicit project filtering' do
      def assert_project_filtering(analysis_job, project_id, expected_count, match: true)
        relation = analysis_job.filter_as_relation

        if match
          expect(relation.to_sql).to match(/"projects"."id" = #{project_id}/)
        else
          expect(relation.to_sql).not_to match(/"projects"."id" = #{project_id}/)
        end

        results = ActiveRecord::Base.connection.exec_query(relation.to_sql)
        expect(results.rows.size).to eq(expected_count)
      end

      before do
        analysis_job.filter = {}
        analysis_job.project_id = nil
        analysis_job.system_job = true
        analysis_job.save!
      end

      it 'checks our assumptions' do
        expect(analysis_job.project_id).to be_nil
        expect(AudioRecording.all.map { |ar| ar.site.projects.first.id }).to be_all(project.id)
      end

      example 'without a project_id no implicit scope is added' do
        analysis_job.project_id = nil
        assert_project_filtering(analysis_job, project.id, 10, match: false)
      end

      example 'with a project_id and implicit scope is added' do
        analysis_job.project_id = project.id
        analysis_job.system_job = false
        assert_project_filtering(analysis_job, project.id, 10)
      end

      example 'with another project_id an implicit scope is added' do
        p2 = create(:project)
        analysis_job.project_id = p2.id
        analysis_job.system_job = false
        assert_project_filtering(analysis_job, p2.id, 0)
      end

      example 'with another project an implicit scope is added' do
        p2 = create(:project)
        analysis_job.project = p2
        analysis_job.system_job = false
        expect(analysis_job.project_id).to eq(p2.id)
        assert_project_filtering(analysis_job, p2.id, 0)
      end
    end

    it 'can filter nothing' do
      analysis_job.filter = {}
      relation = analysis_job.filter_as_relation

      comparison_sql(
        relation.to_sql,
        <<~SQL.squish
          SELECT "audio_recordings"."id"
          FROM "audio_recordings"
          #{permissions_sql}
        SQL
      )

      # execute the query
      results = ActiveRecord::Base.connection.exec_query(relation.to_sql)
      expect(results.rows.size).to eq(10)
    end

    it 'can filter nothing (nil)' do
      analysis_job.filter = nil
      relation = analysis_job.filter_as_relation

      comparison_sql(
        relation.to_sql,
        <<~SQL.squish
          SELECT "audio_recordings"."id"
          FROM "audio_recordings"
          #{permissions_sql}
        SQL
      )

      # execute the query
      results = ActiveRecord::Base.connection.exec_query(relation.to_sql)
      expect(results.rows.size).to eq(10)
    end

    it 'can filter based on a property' do
      analysis_job.filter = {
        duration_seconds: {
          gteq: 300
        }
      }
      relation = analysis_job.filter_as_relation

      comparison_sql(
        relation.to_sql,
        <<~SQL.squish
          SELECT "audio_recordings"."id"
          FROM "audio_recordings"
          #{permissions_sql}
          AND ("audio_recordings"."duration_seconds" >= 300.0)
        SQL
      )

      # execute the query
      results = ActiveRecord::Base.connection.exec_query(relation.to_sql)
      expect(results.rows.size).to eq(8)
    end

    it 'can use or arrays to filter based on a property' do
      analysis_job.filter = {
        or: [
          {
            duration_seconds: {
              eq: 10
            }
          },
          {
            duration_seconds: {
              eq: 3600
            }
          }
        ]
      }
      relation = analysis_job.filter_as_relation

      comparison_sql(
        relation.to_sql,
        <<~SQL.squish
          SELECT "audio_recordings"."id"
          FROM "audio_recordings"
          #{permissions_sql}
          AND ((("audio_recordings"."duration_seconds" = 10.0) OR ("audio_recordings"."duration_seconds" = 3600.0)))
        SQL
      )

      # execute the query
      results = ActiveRecord::Base.connection.exec_query(relation.to_sql)
      expect(results.rows.size).to eq(6)
    end

    it 'can filter based on a association property' do
      analysis_job.filter = {
        'projects.id': {
          eq: project.id
        }
      }
      relation = analysis_job.filter_as_relation

      sql = <<-SQL.squish
        SELECT "audio_recordings"."id"
        FROM "audio_recordings"
        #{permissions_sql}
        AND ("audio_recordings"."id"
        IN (
        SELECT "audio_recordings"."id"
        FROM "audio_recordings"
        LEFT
        OUTER
        JOIN "sites"
        ON "audio_recordings"."site_id" = "sites"."id"
        LEFT
        OUTER
        JOIN "projects_sites"
        ON "sites"."id" = "projects_sites"."site_id"
        LEFT
        OUTER
        JOIN "projects"
        ON "projects_sites"."project_id" = "projects"."id"
        WHERE "projects"."id" = #{project.id}))
      SQL

      comparison_sql(
        relation.to_sql,
        sql
      )

      # execute the query
      results = ActiveRecord::Base.connection.exec_query(relation.to_sql)

      # they all belong to the same project
      expect(results.rows.size).to eq(10)
    end
  end

  describe 'job_progress_query' do
    create_audio_recordings_hierarchy
    let(:script) { create(:script) }
    let(:expected) {
      # 4 possible statuses
      # 5 possible transitions
      # 5 possible results
      {
        # plus 5 for the results, plus 5 for the transitions, all of which
        # are left at status: :new
        status_new_count: 1 + 5 + 5,
        status_queued_count: 1,
        status_working_count: 1,
        status_finished_count: 1,
        transition_empty_count: 1,
        # all items default to transition new on create - only 5
        transition_queue_count: 4 + 1 + 5,
        transition_cancel_count: 1,
        transition_finish_count: 1,
        transition_retry_count: 1,
        # and by default result is nil
        result_empty_count: 4 + 5 + 1,
        result_success_count: 1,
        result_failed_count: 1,
        result_cancelled_count: 1,
        result_killed_count: 1
      }
    }
    let(:analysis_job) { create(:analysis_job, scripts: [script]) }

    before do
      # create some sample data
      AnalysisJobsItem.aasm.state_machine.config.toggle(:no_direct_assignment) do
        AnalysisJobsItem::AVAILABLE_ITEM_STATUS.each do |status|
          item = create(:analysis_jobs_item, analysis_job:, status: :new)
          item.status = status
          item.save!(validate: false)
        end

        [nil].concat(AnalysisJobsItem::ALLOWED_TRANSITIONS).each do |transition|
          item = create(:analysis_jobs_item, analysis_job:)
          item.transition = transition
          item.save!(validate: false)
        end

        [nil].concat(AnalysisJobsItem::ALLOWED_RESULTS).each do |result|
          item = create(:analysis_jobs_item, analysis_job:)
          item.result = result
          item.save!(validate: false)
        end
      end
    end

    it 'returns the expected results' do
      result = analysis_job.job_progress_query

      expect(result).to match(expected)
    end

    it 'has another arel only option' do
      arel = AnalysisJob.job_progress_arel

      expect(arel).to be_a(Arel::Nodes::Node)

      result = AnalysisJob.pick(arel)

      expect(result).to be_a(Hash)
      expect(result.transform_keys(&:to_sym)).to match(expected)
    end
  end

  describe 'state machine' do
    let(:analysis_job) {
      create(:analysis_job)
    }

    pause_all_jobs

    it 'defines the process event' do
      expect(analysis_job).to transition_from(:preparing).to(:processing).on_event(:process)
    end

    it 'defines the suspend event' do
      expect(analysis_job.suspend_count).to eq(0)
      expect(analysis_job).to transition_from(:processing).to(:suspended).on_event(:suspend)
      expect(analysis_job.suspend_count).to eq(1)
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Analysis::RemoteCancelJob)
      clear_pending_jobs
    end

    it 'defines the resume event' do
      expect(analysis_job.resume_count).to eq(0)
      expect(analysis_job).to transition_from(:suspended).to(:processing).on_event(:resume)
      expect(analysis_job.resume_count).to eq(1)
    end

    it 'defines the complete event' do
      expect(analysis_job).to transition_from(:processing).to(:completed).on_event(:complete)

      expect_enqueued_jobs(1, of_class: ActionMailer::MailDeliveryJob)
      clear_pending_jobs
    end

    it 'defines the retry event - which does not work if all items successful' do
      allow(analysis_job).to receive(:are_any_job_items_failed?).and_return(false)

      expect(analysis_job.retry_count).to eq(0)
      expect(analysis_job).not_to allow_event(:retry)
      expect(analysis_job.retry_count).to eq(0)
    end

    it 'defines the retry event' do
      allow(analysis_job).to receive(:are_any_job_items_failed?).and_return(true)

      expect(analysis_job.retry_count).to eq(0)
      expect(analysis_job).to transition_from(:completed).to(:processing).on_event(:retry)
      expect(analysis_job.retry_count).to eq(1)

      expect_enqueued_jobs(1, of_class: ActionMailer::MailDeliveryJob)
      clear_pending_jobs
    end

    it 'defines an amend event' do
      analysis_job.ongoing = true

      expect(analysis_job.amend_count).to eq(0)
      expect(analysis_job).to transition_from(:completed).to(:processing).on_event(:amend)
      expect(analysis_job.amend_count).to eq(1)
    end

    it 'the amend event is only available for ongoing jobs' do
      analysis_job.ongoing = true

      expect(analysis_job.amend_count).to eq(0)
      expect(analysis_job).to transition_from(:completed).to(:processing).on_event(:amend)
      expect(analysis_job.amend_count).to eq(1)
    end
  end
end
