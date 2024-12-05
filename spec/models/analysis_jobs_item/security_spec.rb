# frozen_string_literal: true

describe AnalysisJobsItem do
  describe 'security' do
    describe 'security for results is resolved via audio recordings' do
      # create two separate hierarchies
      create_entire_hierarchy

      let!(:second_project) {
        Creation::Common.create_project(no_access_user)
      }

      # The second analysis jobs item allows us to test for different permission combinations
      # In particular we want to ensure that if someone has access to a project, then they have
      # access to the results
      let!(:second_analysis_jobs_item) {
        project = second_project
        site = Creation::Common.create_site(no_access_user, project)
        audio_recording = Creation::Common.create_audio_recording(owner_user, owner_user, site)
        saved_search.projects << project

        Creation::Common.create_analysis_job_item(analysis_job, script, audio_recording)
      }

      it 'ensures users with access to all projects get all results' do
        # give the original user permissions to access the second project
        create(:read_permission, creator: owner_user, user: reader_user, project: second_project)

        query = Access::ByPermission.analysis_jobs_items(analysis_job, reader_user)

        rows = query.all

        # should have access to both projects
        expect(rows.count).to be 2
        expect(rows[0].id).to be analysis_jobs_item.id
        expect(rows[1].id).to be second_analysis_jobs_item.id
      end

      it 'ensures users with access to one project only get some recordings when new projects added' do
        query = Access::ByPermission.analysis_jobs_items(analysis_job, reader_user)

        rows = query.all

        # should only have access to audio recording from first project
        # the user does not have access to both projects
        expect(rows.count).to be 1
        expect(rows[0].id).to be analysis_jobs_item.id
      end

      it 'ensures users with access to one projects get only some recordings' do
        query = Access::ByPermission.analysis_jobs_items(analysis_job, no_access_user)

        rows = query.all

        # should only have access to the recording from the second project, the user doesn't have access to the original
        # project.
        expect(rows.count).to be 1
        expect(rows[0].id).to be second_analysis_jobs_item.id
      end
    end
  end
end
