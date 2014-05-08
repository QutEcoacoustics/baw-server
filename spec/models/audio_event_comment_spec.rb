require 'spec_helper'

describe AudioEventComment do
  it { should belong_to(:creator).class_name('User').with_foreign_key(:creator_id).inverse_of(:created_audio_event_comments) }
  it { should belong_to(:updater).class_name('User').with_foreign_key(:updater_id).inverse_of(:updated_audio_event_comments) }
  it { should belong_to(:deleter).class_name('User').with_foreign_key(:deleter_id).inverse_of(:deleted_audio_event_comments) }
  it { should belong_to(:flagger).class_name('User').with_foreign_key(:flagger_id).inverse_of(:flagged_audio_event_comments) }

  it { should belong_to(:audio_event).inverse_of(:audio_event_comments) }
end
