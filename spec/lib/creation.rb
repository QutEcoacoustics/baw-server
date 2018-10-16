module Creation
  # accessible in describe/context blocks
  module ExampleGroup
    def create_entire_hierarchy
      prepare_users

      prepare_project

      prepare_permission_owner
      prepare_permission_writer
      prepare_permission_reader

      prepare_tag
      prepare_script

      prepare_site

      prepare_audio_recording
      prepare_bookmark
      prepare_audio_event

      prepare_audio_events_tags
      prepare_audio_event_comment

      prepare_saved_search
      prepare_analysis_job
      prepare_analysis_jobs_item


      prepare_dataset

      prepare_dataset_item

      prepare_progress_event

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

      let!(:no_access_project_creator) { FactoryGirl.create(:user, user_name: 'creator_2') }
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


    # creates an project with public (allow anon) permissions
    # as well as a site, audio recording and dataset item
    def create_anon_hierarchy

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
    def create_audio_recordings_hierarchy
      prepare_users

      prepare_project

      # available after permission system is upgraded
      #prepare_permission_owner
      prepare_permission_writer
      prepare_permission_reader

      prepare_site

      prepare_audio_recording
    end

    def prepare_users
      # these 7 user types must be used to test every endpoint:
      let!(:admin_user) { User.where(user_name: 'Admin').first }
      let!(:admin_token) { Common.create_user_token(admin_user) }

      let!(:owner_user) { FactoryGirl.create(:user, user_name: 'owner user') }
      let!(:owner_token) { Common.create_user_token(owner_user) }

      let!(:writer_user) { FactoryGirl.create(:user, user_name: 'writer') }
      let!(:writer_token) { Common.create_user_token(writer_user) }

      let!(:reader_user) { FactoryGirl.create(:user, user_name: 'reader') }
      let!(:reader_token) { Common.create_user_token(reader_user) }

      let!(:no_access_user) { FactoryGirl.create(:user, user_name: 'no_access') }
      let!(:no_access_token) { Common.create_user_token(no_access_user) }

      let!(:invalid_token) { Common.create_user_token }

      # there is also anonymous users who do not have a token
      # use: standard_request_options({remove_auth: true})

      # harvester is only needed for cases where the api is used by automated systems
      let!(:harvester_user) { User.where(user_name: 'Harvester').first }
      let!(:harvester_token) { Common.create_user_token(harvester_user) }
    end

    def prepare_project
      let!(:project) { Common.create_project(owner_user) }
    end

    def prepare_site
      let!(:site) { Common.create_site(owner_user, project) }
    end

    def prepare_permission_owner
      let!(:owner_permission) { Permission.where(user: owner_user, project: project, level: 'owner').first! }
    end

    def prepare_permission_writer
      let!(:writer_permission) {
        FactoryGirl.create(:write_permission, creator: owner_user, user: writer_user, project: project)
      }
    end

    def prepare_permission_reader
      let!(:reader_permission) {
        FactoryGirl.create(:read_permission, creator: owner_user, user: reader_user, project: project)
      }
    end

    def prepare_project_anon
      let!(:project_anon) { FactoryGirl.create(:project, creator: owner_user, name: 'Anon Project') }
      let!(:permission_anon) { FactoryGirl.create(:permission, creator: owner_user, user: nil, project: project_anon, allow_anonymous: true, level: 'reader') }
    end

    def prepare_project_logged_in
      let!(:project_logged_in) { FactoryGirl.create(:project, creator: owner_user, name: 'Logged In Project') }
      let!(:permission_logged_in) { FactoryGirl.create(:permission, creator: owner_user, user: nil, project: project_logged_in, allow_logged_in: true, level: 'reader') }
    end

    def prepare_tag
      prepare_users
      let!(:tag) { Common.create_tag(admin_user) }
    end

    def prepare_script
      let!(:script) { Common.create_script(admin_user) }
    end

    def prepare_audio_recording
      let!(:audio_recording) { Common.create_audio_recording(writer_user, writer_user, site) }
    end

    def prepare_bookmark
      let!(:bookmark) { Common.create_bookmark(writer_user, audio_recording) }
    end

    def prepare_audio_event
      prepare_audio_recording
      let!(:audio_event) { Common.create_audio_event(writer_user, audio_recording) }
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
      let!(:analysis_job) { Common.create_analysis_job(writer_user, script, saved_search) }
    end

    def prepare_analysis_jobs_item
      prepare_analysis_job
      let!(:analysis_jobs_item) { Common.create_analysis_job_item(analysis_job, audio_recording) }
    end

    def prepare_dataset
      let!(:dataset) { Common.create_dataset(owner_user) }
    end

    def prepare_dataset_item
      prepare_dataset
      prepare_audio_recording
      let!(:dataset_item) { Common.create_dataset_item(admin_user, dataset, audio_recording) }
    end

    def prepare_progress_event
      let!(:default_dataset_item) {
        FactoryGirl.create(:default_dataset_item, creator: writer_user, audio_recording: audio_recording)
      }
      let!(:progress_event) {
        Common.create_progress_event(admin_user, default_dataset_item)
      }
      let!(:progress_event_for_no_access_user) {
        # create a progress event where the creator does not have read permissions
        Common.create_progress_event_full(no_access_user, dataset_item, "played")
      }
    end

    # creates a whole lot of progress events for filter testing
    def prepare_many_progress_events
      let!(:progress_events_stats) {

        creators = [admin_user, owner_user, reader_user, writer_user]
        activities = ["viewed", "played"]
        dataset_items = [dataset_item, no_access_dataset_item]
        num = 4
        result = []

        for c in creators do
          for a in activities do
            for d in dataset_items do
              for n in 1..num do
                if c == admin_user || d != no_access_dataset_item
                  Common.create_progress_event_full(c, d, a)
                  result.push({creator_id: c.id, dataset_item_id: d.id, activity: a})
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
        "Token token=\"#{token}\""
      end

      def create_project(creator)
        FactoryGirl.create(:project, creator: creator)
      end

      def create_site(creator, project)
        site = FactoryGirl.create(:site, :with_lat_long, creator: creator)
        site.projects << project
        site.save!
        site
      end

      def create_tag(creator)
        FactoryGirl.create(:tag, creator: creator)
      end

      def create_script(creator)
        FactoryGirl.create(:script, creator: creator)
      end

      def create_audio_recording(creator, uploader, site)
        FactoryGirl.create(
            :audio_recording,
            :status_ready,
            creator: creator,
            uploader: uploader,
            site: site,
            sample_rate_hertz: 44100)
      end

      def create_bookmark(creator, audio_recording)
        FactoryGirl.create(:bookmark, creator: creator, audio_recording: audio_recording)
      end

      def create_audio_event(creator, audio_recording)
        FactoryGirl.create(:audio_event, creator: creator, audio_recording: audio_recording)
      end

      def create_audio_event_tags(creator, audio_event, tag)
        FactoryGirl.create(:tagging, creator: creator, audio_event: audio_event, tag: tag)
      end

      def create_audio_event_comment(creator, audio_event)
        FactoryGirl.create(:comment, creator: creator, audio_event: audio_event)
      end

      def create_saved_search(creator, project, stored_query = nil)
        if stored_query.nil?
          saved_search = FactoryGirl.create(:saved_search, creator: creator)
        else
          saved_search = FactoryGirl.create(:saved_search, creator: creator, stored_query: stored_query)
        end

        saved_search.projects << project
        saved_search.save!
        saved_search
      end

      def create_analysis_job(creator, script, saved_search)
        FactoryGirl.create(:analysis_job, creator: creator, script: script, saved_search: saved_search)
      end

      def create_analysis_job_item(analysis_job, audio_recording)
        FactoryGirl.create(:analysis_jobs_item, analysis_job: analysis_job, audio_recording: audio_recording)
      end

      def create_dataset(creator)
        FactoryGirl.create(:dataset, creator: creator)
      end

      def create_dataset_item(creator, dataset, audio_recording)
        FactoryGirl.create(:dataset_item, creator: creator, dataset: dataset, audio_recording: audio_recording)
      end

      def create_progress_event(creator, dataset_item)
        FactoryGirl.create(:progress_event, creator: creator, dataset_item: dataset_item)
      end

      def create_progress_event_full(creator, dataset_item, activity)
        FactoryGirl.create(:progress_event, creator: creator, dataset_item: dataset_item, activity: activity)
      end

    end
  end
end