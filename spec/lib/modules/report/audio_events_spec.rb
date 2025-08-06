# frozen_string_literal: true

describe 'Audio Events Report' do
  include SqlHelpers::Example
  subject { Report::AudioEvents.new(options: params) }

  before do
    user = create(:user)
    create(:audio_event_tagging, creator: user, tag: create(:tag), confirmations: ['correct'], users: [user])
  end

  let(:params) {
    {
      start_time: Time.new('2000-03-26T07:06:59').iso8601,
      end_time: Time.new('2000-04-26T07:06:59').iso8601,
      scaling_factor: 1920,
      bucket_size: 'day'
    }
  }

  it 'does something' do
    debugger
    expect(subject).to be_a(Report::AudioEvents)
    subject.to_sql
  end
end
