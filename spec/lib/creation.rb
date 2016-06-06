module Creation
  # accessible in describe/context blocks
  module ExampleGroup
    def create_entire_hierarchy
      prepare_users

      prepare_project

      # available after permission system is upgraded
      #prepare_permission_owner
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
      let!(:admin_user) { FactoryGirl.create(:admin) }
      let!(:admin_token) { Common.create_user_token(admin_user) }

      let!(:harvester_user) { FactoryGirl.create(:harvester) }
      let!(:harvester_token) { Common.create_user_token(harvester_user) }

      let!(:owner_user) { FactoryGirl.create(:user, user_name: 'owner user') }
      let!(:owner_token) { Common.create_user_token(owner_user) }

      let!(:writer_user) { FactoryGirl.create(:user, user_name: 'writer') }
      let!(:writer_token) { Common.create_user_token(writer_user) }

      let!(:reader_user) { FactoryGirl.create(:user, user_name: 'reader') }
      let!(:reader_token) { Common.create_user_token(reader_user) }

      let!(:other_user) { FactoryGirl.create(:user, user_name: 'other') }
      let!(:other_token) { Common.create_user_token(other_user) }

      let!(:unconfirmed_user) { FactoryGirl.create(:unconfirmed_user) }
      let!(:unconfirmed_token) { Common.create_user_token(unconfirmed_user) }

      let!(:invalid_token) { Common.create_user_token }
    end

    def prepare_project
      prepare_users
      let!(:project) { Common.create_project(owner_user) }
    end

    def prepare_site
      prepare_project
      let!(:site) { Common.create_site(writer_user, project) }
    end

    def prepare_permission_owner
      prepare_project
      let!(:owner_permission) { Permission.where(user: owner_user, project: project, level: 'owner').first! }
    end

    def prepare_permission_writer
      prepare_project
      let!(:writer_permission) { FactoryGirl.create(:write_permission, creator: owner_user, user: writer_user, project: project) }
    end

    def prepare_permission_reader
      prepare_project
      let!(:reader_permission) { FactoryGirl.create(:read_permission, creator: owner_user, user: reader_user, project: project) }
    end

    def prepare_tag
      prepare_users
      let!(:tag) { Common.create_tag(admin_user) }
    end

    def prepare_script
      prepare_users
      let!(:script) { Common.create_script(admin_user) }
    end

    def prepare_audio_recording
      prepare_site
      let!(:audio_recording) { Common.create_audio_recording(writer_user, writer_user, site) }
    end

    def prepare_bookmark
      prepare_audio_recording
      let!(:bookmark) { Common.create_bookmark(writer_user, audio_recording) }
    end

    def prepare_audio_event
      prepare_audio_recording
      let!(:audio_event) { Common.create_audio_event(writer_user, audio_recording) }
    end

    def prepare_audio_events_tags
      prepare_audio_event
      prepare_tag
      let!(:tagging) { Common.create_audio_event_tags(writer_user, audio_event, tag) }
    end

    def prepare_audio_event_comment
      prepare_audio_event
      let!(:audio_event_comment) { Common.create_audio_event_comment(writer_user, audio_event) }
    end

    def prepare_saved_search
      prepare_project
      let!(:saved_search) { Common.create_saved_search(writer_user, project) }
    end

    def prepare_analysis_job
      prepare_saved_search
      let!(:analysis_job) { Common.create_analysis_job(writer_user, script, saved_search) }
    end

    def prepare_analysis_jobs_item
      prepare_analysis_job
      let!(:analysis_jobs_item) { Common.create_analysis_job_item(analysis_job, audio_recording) }
    end
  end

  # Accessible inside `it` blocks
  module Example

  end

  class Common
    class << self

      def create_user_token(user = nil)
        token = user.blank? ? '11faketoken11' : user.authentication_token
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
        FactoryGirl.create(:audio_recording, :status_ready, creator: creator, uploader: uploader, site: site)
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

    end
  end
end