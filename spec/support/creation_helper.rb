# frozen_string_literal: true

module Creation
  # accessible in describe/context blocks
  module ExampleGroup # rubocop:disable Metrics/ModuleLength
    def create_standard_cms_pages
      before do
        load Rails.root / 'db' / 'cms_seeds' / 'cms_seeds.rb'
      end
    end

    def create_entire_hierarchy
      prepare_users

      prepare_project

      prepare_permission_owner
      prepare_permission_writer
      prepare_permission_reader

      prepare_tag
      prepare_provenance
      prepare_script

      prepare_region
      prepare_site

      prepare_audio_recording
      prepare_audio_recording_statistic
      prepare_bookmark

      prepare_audio_event

      prepare_audio_events_tags
      prepare_audio_event_comment

      prepare_verification

      prepare_harvest
      prepare_harvest_item

      prepare_saved_search
      prepare_analysis_job
      prepare_analysis_jobs_item

      prepare_audio_event_import
      prepare_audio_event_import_file

      prepare_dataset

      prepare_dataset_item

      prepare_progress_event

      create_study_hierarchy
    end

    # similar to create entire hierarchy
    # but the project does not give any permissions to the owner writer reader users
    # So, it allows testing whether the get methods are correctly handling results that
    # the owner/reader/writer does not have read access to.
    # Here we create:
    #   - A new user, creator_2, who will be the owner/creator of the project
    #   - project with creator_2 as creator called no_access_project. This project has no permissions applied to it
    #   - site under that project called no_access_site, with creator_2 as creator
    #   - audio recording under that site called no_access_audio_recording, with creator_2 as creator
    #   - 1 dataset item under that audio_recording called no_access_dataset_item, with admin as creator

    def create_no_access_hierarchy
      let!(:no_access_project_creator) { FactoryBot.create(:user, user_name: 'creator_2') }
      let!(:no_access_project) { Common.create_project(no_access_project_creator) }
      let!(:no_access_site) { Common.create_site(no_access_project_creator, no_access_project) }
      let!(:no_access_audio_recording) {
        Common.create_audio_recording(no_access_project_creator, no_access_project_creator, no_access_site)
      }
      let!(:no_access_dataset_item) { Common.create_dataset_item(admin_user, dataset, no_access_audio_recording) }
      let!(:no_access_progress_event) {
        Common.create_progress_event(admin_user, no_access_dataset_item)
      }
    end

    # creates a project with public (allow anon) permissions
    # as well as a site, audio recording and dataset item
    def create_anon_hierarchy
      prepare_users
      prepare_project_anon

      let!(:site_anon) {
        Common.create_site(owner_user, project_anon)
      }

      let!(:audio_recording_anon) {
        Common.create_audio_recording(writer_user, writer_user, site_anon)
      }

      let!(:dataset_item_anon) {
        Common.create_dataset_item(admin_user, dataset, audio_recording_anon)
      }
    end

    # create audio recordings and all parent entities
    def create_audio_recordings_hierarchy(project_prepare_method = nil)
      prepare_users

      if project_prepare_method.nil?
        prepare_project
      else
        project_prepare_method.call(:project)
      end

      # available after permission system is upgraded
      prepare_permission_owner
      prepare_permission_writer
      prepare_permission_reader

      prepare_region
      prepare_site

      prepare_audio_recording
    end

    # create study, question, response hierarchy
    def create_study_hierarchy
      prepare_study
      prepare_question
      prepare_user_response
    end

    # assumes create_audio_recordings_hierarchy has been called (or at least
    # site exists)
    def create_analysis_jobs_matrix(analysis_jobs_count: 1, scripts_count: 1, audio_recordings_count: 1)
      let!(:analysis_jobs_matrix) {
        scripts = create_list(:script, scripts_count)
        analysis_jobs = create_list(
          :analysis_job,
          analysis_jobs_count,
          scripts: [],
          creator: owner_user,
          project:
        )
        audio_recordings = create_list(:audio_recording, audio_recordings_count, site:)
        analysis_jobs_items = []

        analysis_jobs.each do |analysis_job|
          # it seems the factory is too insistent on saving the scripts
          analysis_job.scripts.clear
          analysis_job.save!(validate: false)

          scripts.each do |script|
            AnalysisJobsScript.new(analysis_job:, script:).save!

            audio_recordings.each do |audio_recording|
              item = AnalysisJobsItem.new(
                analysis_job:,
                audio_recording:,
                script:,
                transition: AnalysisJobsItem::TRANSITION_QUEUE
              )

              item.save!

              analysis_jobs_items.push(item)
            end
          end

          analysis_job.reload
        end

        expect(AnalysisJobsItem.count).to eq(analysis_jobs_count * scripts_count * audio_recordings_count)

        {
          analysis_jobs:,
          scripts:,
          audio_recordings:,
          analysis_jobs_items:
        }
      }
    end

    def prepare_study
      let!(:default_study) { Common.create_study(admin_user, default_dataset) }
      let!(:study) { Common.create_study(admin_user, dataset) }
    end

    def prepare_question
      let!(:default_question) { Common.create_question(admin_user, default_study) }
      let!(:question) { Common.create_question(admin_user, study) }
    end

    def prepare_user_response
      # named to avoid name collision with rspec 'response'
      let!(:default_user_response) {
        Common.create_user_response(reader_user, default_dataset_item, default_study, default_question)
      }
      let!(:user_response) { Common.create_user_response(reader_user, dataset_item, study, question) }
    end

    def prepare_users
      # these 7 user types must be used to test every endpoint:
      let!(:admin_user) { User.where(user_name: 'Admin').first }
      let!(:admin_token) { Common.create_user_token(admin_user) }

      let!(:owner_user) { FactoryBot.create(:user, user_name: 'owner user') }
      let!(:owner_token) { Common.create_user_token(owner_user) }

      let!(:writer_user) { FactoryBot.create(:user, user_name: 'writer', skip_creation_email: true) }
      let!(:writer_token) { Common.create_user_token(writer_user) }

      let!(:reader_user) { FactoryBot.create(:user, user_name: 'reader', skip_creation_email: true) }
      let!(:reader_token) { Common.create_user_token(reader_user) }

      # implicitly not allowed access (we don't encode explicit non-access in our permissions structure)
      let!(:no_access_user) { FactoryBot.create(:user, user_name: 'no_access', skip_creation_email: true) }
      let!(:no_access_token) { Common.create_user_token(no_access_user) }

      # i.e. a user with a token not generated by us
      let!(:invalid_token) { Common.create_user_token }

      # there is also anonymous users who do not have a token
      # use: standard_request_options({remove_auth: true})
      let!(:no_token) { nil }
      # aliased no_token for readability
      let!(:anonymous_token) { nil }

      # harvester is only needed for cases where the api is used by automated systems
      let!(:harvester_user) { User.where(user_name: 'Harvester').first }
      let!(:harvester_token) { Common.create_user_token(harvester_user) }

      let!(:all_users) {
        # nil represents a user who is not logged in
        [admin_user, harvester_user, owner_user, writer_user, reader_user, no_access_user, nil]
      }
    end

    def prepare_project(alternate_name = nil)
      let!(:project) { Common.create_project(owner_user) }
      let!(alternate_name) { project_anon } if alternate_name && alternate_name != :project
    end

    def prepare_anonymous_access(project_name)
      let!(:permission_anon) {
        FactoryBot.create(:permission, creator: owner_user, user: nil, project: send(project_name), allow_anonymous: true,
          level: 'reader')
      }
    end

    def prepare_logged_in_access(project_name)
      let!(:permission_logged_in) {
        FactoryBot.create(:permission, creator: owner_user, user: nil, project: send(project_name), allow_logged_in: true,
          level: 'reader')
      }
    end

    def prepare_project_anon(alternate_name = nil)
      let!(:project_anon) {
        FactoryBot.create(:project, creator: owner_user, name: 'Anon Project')
      }
      let!(alternate_name) { project_anon } if alternate_name
      prepare_anonymous_access(:project_anon)
    end

    def prepare_project_logged_in(alternate_name = nil)
      let!(:project_logged_in) {
        FactoryBot.create(:project, creator: owner_user, name: 'Logged In Project')
      }
      let!(alternate_name) { project_logged_in } if alternate_name
      prepare_logged_in_access(:project_logged_in)
    end

    def prepare_project_anon_and_logged_in(alternate_name = nil)
      let!(:project_anon_and_logged_in) {
        FactoryBot.create(:project, creator: owner_user, name: 'Anon & Logged In Project')
      }
      let!(alternate_name) { project_anon_and_logged_in } if alternate_name

      prepare_anonymous_access(:project_anon_and_logged_in)
      prepare_logged_in_access(:project_anon_and_logged_in)
    end

    def prepare_harvest
      prepare_harvest_with_mappings
    end

    def prepare_harvest_with_mappings(&block)
      let!(:harvest) {
        h = Common.create_harvest(owner_user, project)
        unless block.nil?
          h.mappings = instance_eval(&block).map { |hash|
            ::BawWorkers::Jobs::Harvest::Mapping.new(hash)
          }

          h.save!
        end
        h
      }
    end

    def prepare_harvest_item
      let!(:harvest_item) { Common.create_harvest_item(harvest, audio_recording, owner_user) }
    end

    def prepare_region
      let!(:region) { Common.create_region(owner_user, project) }
    end

    def prepare_site
      let!(:site) { Common.create_site(owner_user, project, region:) }
    end

    def prepare_permission_owner
      let!(:owner_permission) { Permission.where(user: owner_user, project:, level: 'owner').first! }
    end

    def prepare_permission_writer
      let!(:writer_permission) {
        FactoryBot.create(:write_permission, creator: owner_user, user: writer_user, project:)
      }
    end

    def prepare_permission_reader
      let!(:reader_permission) {
        FactoryBot.create(:read_permission, creator: owner_user, user: reader_user, project:)
      }
    end

    def prepare_tag
      prepare_users
      let!(:tag) { Common.create_tag(admin_user) }
    end

    def prepare_provenance
      let!(:provenance) { Common.create_provenance(admin_user) }
    end

    def prepare_script
      let!(:script) { Common.create_script(admin_user, provenance) }
    end

    def prepare_audio_recording
      let!(:audio_recording) { Common.create_audio_recording(writer_user, writer_user, site) }
    end

    def prepare_audio_recording_statistic
      let!(:audio_recording_statistic) { Common.create_audio_recording_statistic(audio_recording) }
    end

    def prepare_bookmark
      let!(:bookmark) { Common.create_bookmark(writer_user, audio_recording) }
    end

    def prepare_audio_event_import
      let!(:audio_event_import) { Common.create_audio_event_import(writer_user) }
    end

    def prepare_audio_event_import_file
      let!(:audio_event_import_file) {
        Common.create_audio_event_import_file(audio_event_import, analysis_jobs_item)
      }
    end

    def prepare_audio_event
      prepare_audio_recording
      let!(:audio_event) { Common.create_audio_event(writer_user, audio_recording, audio_event_import_file) }
    end

    def prepare_audio_events_tags
      let!(:tagging) { Common.create_audio_event_tags(writer_user, audio_event, tag) }
    end

    def prepare_audio_event_comment
      let!(:audio_event_comment) { Common.create_audio_event_comment(writer_user, audio_event) }
    end

    def prepare_saved_search
      let!(:saved_search) { Common.create_saved_search(writer_user, project) }
    end

    def prepare_analysis_job
      let!(:analysis_job) { Common.create_analysis_job(writer_user, script, project) }
    end

    def prepare_analysis_jobs_item
      let!(:analysis_jobs_item) {
        Common.create_analysis_job_item(analysis_job, script, audio_recording)
      }
    end

    def prepare_dataset
      let!(:default_dataset) { Dataset.default_dataset }
      let!(:dataset) { Common.create_dataset(owner_user) }
    end

    def prepare_dataset_item
      let!(:default_dataset_item) { Common.create_dataset_item(admin_user, default_dataset, audio_recording) }
      let!(:dataset_item) { Common.create_dataset_item(admin_user, dataset, audio_recording) }
    end

    def prepare_progress_event
      let!(:default_progress_event) {
        Common.create_progress_event(admin_user, default_dataset_item)
      }
      let!(:progress_event) {
        Common.create_progress_event(admin_user, dataset_item)
      }
      let!(:progress_event_for_no_access_user) {
        # create a progress event where the creator does not have read permissions
        Common.create_progress_event_full(no_access_user, dataset_item, 'played')
      }
    end

    def prepare_verification
      let!(:verification) { Common.create_verification(writer_user, audio_event, tag) }
    end

    # creates a whole lot of progress events for filter testing
    def prepare_many_progress_events
      let!(:progress_events_stats) {
        creators = [admin_user, owner_user, reader_user, writer_user]
        activities = ['viewed', 'played']
        dataset_items = [dataset_item, no_access_dataset_item]
        num = 4
        result = []

        creators.each do |c|
          activities.each do |a|
            dataset_items.each do |d|
              (1..num).each do |_n|
                if c == admin_user || d != no_access_dataset_item
                  Common.create_progress_event_full(c, d, a)
                  result.push(creator_id: c.id, dataset_item_id: d.id, activity: a)
                end
              end
            end
          end
        end

        return result
      }
    end
  end

  # Accessible inside `it` blocks
  module Example
  end

  class Common
    class << self
      def create_user_token(user = nil)
        token = user.blank? ? 'NOT_A_VALID_TOKEN' : user.authentication_token

        if token.blank?
          token = user.ensure_authentication_token
          user.save!
        end

        "Token token=\"#{token}\""
      end

      def create_project(creator)
        FactoryBot.create(:project, creator:, allow_audio_upload: true)
      end

      def create_harvest(creator, project)
        FactoryBot.create(:harvest, creator:, project:)
      end

      def create_harvest_item(harvest, audio_recording, uploader)
        FactoryBot.create(:harvest_item, harvest:, audio_recording:, uploader:)
      end

      def create_region(creator, project)
        FactoryBot.create(:region, creator:, project:)
      end

      def create_site(creator, project, region: nil, name: nil)
        site = FactoryBot.create(:site, :with_lat_long, creator:, region:, projects: [project])
        site.name = name unless name.nil?
        site.save!
        site
      end

      def create_tag(creator)
        FactoryBot.create(:tag, creator:)
      end

      def create_verification(creator, audio_event, tag)
        FactoryBot.create(:verification, creator:, audio_event:, tag:)
      end

      def create_provenance(creator)
        FactoryBot.create(:provenance, creator:)
      end

      def create_script(creator, provenance = nil)
        FactoryBot.create(:script, creator:, provenance:)
      end

      def create_audio_recording(creator, uploader, site)
        FactoryBot.create(
          :audio_recording,
          :status_ready,
          creator:,
          uploader:,
          site:,
          sample_rate_hertz: 44_100
        )
      end

      def create_audio_recording_statistic(audio_recording)
        FactoryBot.create(:audio_recording_statistics, audio_recording:)
      end

      def create_bookmark(creator, audio_recording)
        FactoryBot.create(:bookmark, creator:, audio_recording:)
      end

      def create_audio_event_import(creator)
        FactoryBot.create(:audio_event_import, creator:, updater: creator)
      end

      def create_audio_event_import_file(audio_event_import, analysis_jobs_item)
        FactoryBot.create(:audio_event_import_file, :with_path,
          audio_event_import:,
          analysis_jobs_item:)
      end

      def create_audio_event(creator, audio_recording, audio_event_import_file = nil)
        FactoryBot.create(:audio_event, creator:, audio_recording:, audio_event_import_file:)
      end

      def create_audio_event_tags(creator, audio_event, tag)
        FactoryBot.create(:tagging, creator:, audio_event:, tag:)
      end

      def create_audio_event_comment(creator, audio_event)
        FactoryBot.create(:comment, creator:, audio_event:)
      end

      def create_saved_search(creator, project, stored_query = nil)
        saved_search = if stored_query.nil?
                         FactoryBot.create(:saved_search, creator:)
                       else
                         FactoryBot.create(:saved_search, creator:, stored_query:)
                       end

        saved_search.projects << project
        saved_search.save!
        saved_search
      end

      def create_analysis_job(creator, script, project, filter = {})
        FactoryBot.create(:analysis_job, creator:, project:, scripts: [script], filter:)
      end

      def create_analysis_job_item(analysis_job, script, audio_recording)
        FactoryBot.create(:analysis_jobs_item, analysis_job:, script:, audio_recording:)
      end

      def create_dataset(creator)
        FactoryBot.create(:dataset, creator:)
      end

      def create_dataset_item(creator, dataset, audio_recording)
        FactoryBot.create(:dataset_item, creator:, dataset:, audio_recording:)
      end

      def create_progress_event(creator, dataset_item)
        FactoryBot.create(:progress_event, creator:, dataset_item:)
      end

      def create_progress_event_full(creator, dataset_item, activity)
        FactoryBot.create(:progress_event, creator:, dataset_item:, activity:)
      end

      def create_study(creator, dataset)
        FactoryBot.create(:study, creator:, dataset:)
      end

      def create_question(creator, study)
        question = FactoryBot.build(:question, creator:)
        question.studies << study
        question.save!
        question
      end

      def create_user_response(creator, dataset_item, study, question)
        FactoryBot.create(:response, creator:, dataset_item:, study:, question:)
      end
    end
  end
end
