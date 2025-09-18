# frozen_string_literal: true

describe 'Audio Event Summary' do
  include SqlHelpers::Example
  subject { Report::Ctes::AudioEventSummary.new(options: params) }

  before do
    user = create(:user)
    create(:audio_event_tagging, creator: user, tag: create(:tag), confirmations: ['correct'], users: [user])
  end

  let(:params) {
    {
      start_time: Time.new('2000-03-26T07:06:59').iso8601,
      end_time: Time.new('2000-04-26T07:06:59').iso8601,
      scaling_factor: 1920,
      lower_field: :recorded_date,
      upper_field: :end_date,
      interval: '1 day'
    }
  }

  it 'executes' do
    expect(subject).to be_a(Report::Ctes::AudioEventSummary)
    expect(subject.execute).to be_a(PG::Result)
  end
end
