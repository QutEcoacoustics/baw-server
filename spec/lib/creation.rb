module Creation
  module ExampleGroup
    def create_entire_hierarchy
      let!(:admin_user) { FactoryGirl.create(:admin) }
      let!(:owner_user) { FactoryGirl.create(:user, user_name: 'owner user') }
      let!(:writer_user) { FactoryGirl.create(:user, user_name: 'writer') }
      let!(:reader_user) { FactoryGirl.create(:user, user_name: 'reader') }
      let!(:other_user) { FactoryGirl.create(:user, user_name: 'other') }
      let!(:unconfirmed_user) { FactoryGirl.create(:unconfirmed_user) }
      let!(:harvester_user) { FactoryGirl.create(:harvester) }

      let!(:project) { FactoryGirl.create(:project, creator: owner_user) }

      let!(:owner_permission) { Permission.where(user: owner_user, project: project, level: 'owner').first! }
      let!(:writer_permission) { FactoryGirl.create(:write_permission, creator: owner_user, user: writer_user, project: project) }
      let!(:reader_permission) { FactoryGirl.create(:read_permission, creator: owner_user, user: reader_user, project: project) }

      let!(:tag) { FactoryGirl.create(:tag, creator: admin_user) }
      let!(:script) { FactoryGirl.create(:script, creator: admin_user) }

      let!(:site) {
        site = FactoryGirl.create(:site, :with_lat_long, creator: writer_user)
        site.projects << project
        site.save!
        site
      }

      let!(:audio_recording) { FactoryGirl.create(:audio_recording, :status_ready, creator: writer_user, uploader: writer_user, site: site) }
      let!(:bookmark) { FactoryGirl.create(:bookmark, creator: writer_user, audio_recording: audio_recording) }
      let!(:audio_event) { FactoryGirl.create(:audio_event, creator: writer_user, audio_recording: audio_recording) }

      let!(:tagging) { FactoryGirl.create(:tagging, creator: writer_user, audio_event: audio_event, tag: tag) }
      let!(:audio_event_comment) { FactoryGirl.create(:comment, creator: writer_user, audio_event: audio_event) }

      let!(:saved_search) {
        saved_search = FactoryGirl.create(:saved_search, creator: writer_user)
        saved_search.projects << project
        saved_search.save!
        saved_search
      }

      let!(:analysis_job) { FactoryGirl.create(:analysis_job, creator: writer_user, script: script, saved_search: saved_search) }

      let!(:admin_token) { create_user_token(admin_user) }
      let!(:writer_token) { create_user_token(writer_user) }
      let!(:reader_token) { create_user_token(reader_user) }
      let!(:other_token) { create_user_token(other_user) }
      let!(:unconfirmed_token) { create_user_token(unconfirmed_user) }
      let!(:invalid_token) { create_user_token }
      let!(:harvester_token) { create_user_token(harvester_user) }
    end
  end

  module Example
    def create_user_token(user = nil)
      token = user.blank? ? '11faketoken11' : user.authentication_token
      "Token token=\"#{token}\""
    end
  end
end