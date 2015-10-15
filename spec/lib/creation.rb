module Creation
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
    end

    def prepare_users
      let!(:admin_user) { FactoryGirl.create(:admin) }
      let!(:admin_token) { create_user_token(admin_user) }

      let!(:harvester_user) { FactoryGirl.create(:harvester) }
      let!(:harvester_token) { create_user_token(harvester_user) }

      let!(:owner_user) { FactoryGirl.create(:user, user_name: 'owner user') }
      let!(:owner_token) { create_user_token(owner_user) }

      let!(:writer_user) { FactoryGirl.create(:user, user_name: 'writer') }
      let!(:writer_token) { create_user_token(writer_user) }

      let!(:reader_user) { FactoryGirl.create(:user, user_name: 'reader') }
      let!(:reader_token) { create_user_token(reader_user) }

      let!(:other_user) { FactoryGirl.create(:user, user_name: 'other') }
      let!(:other_token) { create_user_token(other_user) }

      let!(:unconfirmed_user) { FactoryGirl.create(:unconfirmed_user) }
      let!(:unconfirmed_token) { create_user_token(unconfirmed_user) }

      let!(:invalid_token) { create_user_token }
    end

    def prepare_project
      prepare_users
      let!(:project) { FactoryGirl.create(:project, creator: owner_user) }
    end

    def prepare_site
      prepare_project
      let!(:site) {
        site = FactoryGirl.create(:site, :with_lat_long, creator: writer_user)
        site.projects << project
        site.save!
        site
      }
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
      let!(:tag) { FactoryGirl.create(:tag, creator: admin_user) }
    end

    def prepare_script
      prepare_users
      let!(:script) { FactoryGirl.create(:script, creator: admin_user) }
    end

    def prepare_audio_recording
      prepare_site
      let!(:audio_recording) { FactoryGirl.create(:audio_recording, :status_ready, creator: writer_user, uploader: writer_user, site: site) }
    end

    def prepare_bookmark
      prepare_audio_recording
      let!(:bookmark) { FactoryGirl.create(:bookmark, creator: writer_user, audio_recording: audio_recording) }
    end

    def prepare_audio_event
      prepare_audio_recording
      let!(:audio_event) { FactoryGirl.create(:audio_event, creator: writer_user, audio_recording: audio_recording) }
    end

    def prepare_audio_events_tags
      prepare_audio_event
      prepare_tag
      let!(:tagging) { FactoryGirl.create(:tagging, creator: writer_user, audio_event: audio_event, tag: tag) }
    end

    def prepare_audio_event_comment
      prepare_audio_event
      let!(:audio_event_comment) { FactoryGirl.create(:comment, creator: writer_user, audio_event: audio_event) }
    end

    def prepare_saved_search
      prepare_project
      let!(:saved_search) {
        saved_search = FactoryGirl.create(:saved_search, creator: writer_user)
        saved_search.projects << project
        saved_search.save!
        saved_search
      }
    end

    def prepare_analysis_job
      prepare_saved_search
      let!(:analysis_job) { FactoryGirl.create(:analysis_job, creator: writer_user, script: script, saved_search: saved_search) }
    end
  end

  module Example
    def create_user_token(user = nil)
      token = user.blank? ? '11faketoken11' : user.authentication_token
      "Token token=\"#{token}\""
    end
  end
end