require 'spec_helper'

describe User do
  #pending "add some examples to (or delete) #{__FILE__}"

  # this should pass, but the paperclip implementation of validate_attachment_content_type is buggy.
  # it { should validate_attachment_content_type(:image)
  #                 .allowing('image/gif', 'image/jpeg', 'image/jpg','image/png', 'image/x-png', 'image/pjpeg')
  #                 .rejecting('text/xml', 'image_maybe/abc', 'some_image/png','text/plain') }

  it 'has a valid factory' do
    u = create(:user)

    u.should be_valid
  end

  it { should have_many(:accessible_projects).class_name('Project').through(:permissions).source(:project) }
  it { should have_many(:readable_projects).class_name('Project').through(:permissions).source(:project) }
  it { should have_many(:writable_projects).class_name('Project').through(:permissions).source(:project) }

  it { should have_many(:created_audio_events).class_name('AudioEvent').with_foreign_key(:creator_id).inverse_of(:creator) }
  it { should have_many(:updated_audio_events).class_name('AudioEvent').with_foreign_key(:updater_id).inverse_of(:updater) }
  it { should have_many(:deleted_audio_events).class_name('AudioEvent').with_foreign_key(:deleter_id).inverse_of(:deleter) }

  it { should have_many(:created_audio_event_comments).class_name('AudioEventComment').with_foreign_key(:creator_id).inverse_of(:creator) }
  it { should have_many(:updated_audio_event_comments).class_name('AudioEventComment').with_foreign_key(:updater_id).inverse_of(:updater) }
  it { should have_many(:deleted_audio_event_comments).class_name('AudioEventComment').with_foreign_key(:deleter_id).inverse_of(:deleter) }
  it { should have_many(:flagged_audio_event_comments).class_name('AudioEventComment').with_foreign_key(:flagger_id).inverse_of(:flagger) }

  it { should have_many(:created_audio_recordings).class_name('AudioRecording').with_foreign_key(:creator_id).inverse_of(:creator) }
  it { should have_many(:updated_audio_recordings).class_name('AudioRecording').with_foreign_key(:updater_id).inverse_of(:updater) }
  it { should have_many(:deleted_audio_recordings).class_name('AudioRecording').with_foreign_key(:deleter_id).inverse_of(:deleter) }
  it { should have_many(:uploaded_audio_recordings).class_name('AudioRecording').with_foreign_key(:uploader_id).inverse_of(:uploader) }

  it { should have_many(:created_taggings).class_name('Tagging').with_foreign_key(:creator_id).inverse_of(:creator) }
  it { should have_many(:updated_taggings).class_name('Tagging').with_foreign_key(:updater_id).inverse_of(:updater) }

  it { should have_many(:created_bookmarks).class_name('Bookmark').with_foreign_key(:creator_id).inverse_of(:creator) }
  it { should have_many(:updated_bookmarks).class_name('Bookmark').with_foreign_key(:updater_id).inverse_of(:updater) }

  it { should have_many(:created_datasets).class_name('Dataset').with_foreign_key(:creator_id).inverse_of(:creator) }
  it { should have_many(:updated_datasets).class_name('Dataset').with_foreign_key(:updater_id).inverse_of(:updater) }

  it { should have_many(:created_jobs).class_name('Job').with_foreign_key(:creator_id).inverse_of(:creator) }
  it { should have_many(:updated_jobs).class_name('Job').with_foreign_key(:updater_id).inverse_of(:updater) }
  it { should have_many(:deleted_jobs).class_name('Job').with_foreign_key(:deleter_id).inverse_of(:deleter) }


  it { should validate_presence_of(:user_name) }
  it 'is invalid without a user_name' do
    build(:user, user_name: nil).should_not be_valid
  end
  it { should validate_uniqueness_of(:user_name) }
  it 'is invalid with a duplicate user_name (case-insensitive)' do
    create(:user, user_name: 'the_same name')
    u = build(:user, user_name: 'tHE_Same naMe')
    u.should_not be_valid
    u.should have(1).error_on(:user_name)
  end
  restricted_user_names = %w(admin harvester analysis_runner)
  it { should ensure_exclusion_of(:user_name).in_array(restricted_user_names) }
  restricted_user_names.each { |special_name|
    it "should ensure username cannot be set to #{special_name}" do
      build(:user, user_name: special_name).should_not be_valid
    end
    # it "should ensure username can be set to #{special_name} (if set_user_name_exclusion_list is true)" do
    #   u = build(:user)
    #   u.skip_user_name_exclusion_list = true
    #   u.user_name =special_name
    #   u.should be_valid
    # end

  }

  # it 'is valid with a duplicate display_name (case-insensitive)' do
  #   create(:user, display_name: 'the_same name')
  #   u = build(:user, display_name: 'tHE_Same naMe')
  #   u.should be_valid
  # end

  it { should validate_presence_of(:email) }
  it 'is invalid with a duplicate email (case-insensitive)' do
    u1 = create(:user, email: 'the_same+email@anthony.is.AWESOME')
    u = build(:user, email: 'tHE_same+eMAIl@Anthony.IS.awesome')
    u.should_not be_valid
    u.should have(1).error_on(:email)
  end
  context 'basic email syntax checking' do
    emails = [
        ['example@dooby.com', true],
        #['example@dooby', false], # devise format allows this
        ['@dooby.com', false],
        ['example.dooby.com', false],
        ['lololololol', false],
        ['example@dooby.com.au', true],
        ['@.', false],
        ['.', false],
        ['@', false]
    ]
    emails.each { |email_case|
      email = email_case[0]
      pass = email_case[1]
      it "should #{'not' if !pass} allow this '#{email}' email address" do
        if pass
          build(:user, email: email).should be_valid
        else
          build(:user, email: email).should_not be_valid
        end
      end

    }
  end

  # context 'display_name is optional if an email is provided are required to be valid' do
  #   it 'should NOT allow just display_name (email is always requried)' do
  #     u = build(:user, {display_name: 'Barney Stinson', email: nil})
  #     u.should_not be_valid
  #   end
  #   it 'should allow just email' do
  #     build(:user, {display_name: nil, email: 'barney@thebrocode.org'}).should be_valid
  #   end
  #   it 'should allow display_name and email address (at the same time)' do
  #     build(:user, {display_name: 'Barney Stinson', email: 'barney@thebrocode.org'}).should be_valid
  #   end
  #   it 'should should not allow empty display_name and email fields' do
  #     build(:user, {display_name: nil, email: nil}).should_not be_valid
  #   end
  # end
  end
