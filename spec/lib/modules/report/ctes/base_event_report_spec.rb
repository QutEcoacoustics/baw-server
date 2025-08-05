# frozen_string_literal: true

describe Report::Ctes::BaseEventReport do
  before do
    create(:audio_event_tagging,
      tag: create(:tag),
      confirmations: ['correct'],
      users: [create(:user)])
  end

  it 'executes' do
    expect(Report::Ctes::BaseEventReport.new.execute).to be_a(PG::Result)
  end
end
