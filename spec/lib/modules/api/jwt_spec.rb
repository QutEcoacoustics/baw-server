# frozen_string_literal: true

describe Api::Jwt do
  it 'can encode and decode a subject' do
    token = Api::Jwt.encode(subject: 123)

    decoded_payload = Api::Jwt.decode(token)

    expect(decoded_payload.subject).to eq(123)
    expect(decoded_payload).to be_valid

    expect(decoded_payload.expiration).to \
      be_within(10.seconds).of(24.hours.from_now)
  end

  it 'can encode and decode an action and resource' do
    token = Api::Jwt.encode(subject: 0, resource: :projects, action: :show)

    decoded_payload = Api::Jwt.decode(token)

    expect(decoded_payload.subject).to eq(0)
    expect(decoded_payload.resource).to eq(:projects)
    expect(decoded_payload.action).to eq(:show)
    expect(decoded_payload).to be_valid

    expect(decoded_payload.expiration).to \
      be_within(10.seconds).of(24.hours.from_now)
  end

  it 'will validate a resource symbol' do
    expect {
      Api::Jwt.encode(subject: 0, resource: :monkeys, action: :show)
    }.to raise_error(ArgumentError, 'JWT resource claim must be a valid controller')
  end

  it 'cannot decode a token with a bad secret' do
    token = JWT.encode(
      { 'sub' => 123 },
      'iamadifferentsecret',
      Api::Jwt::ALGORITHM
    )

    decoded_payload = Api::Jwt.decode(token)

    expect(decoded_payload).not_to be_valid
    expect(decoded_payload.subject).to be_nil
  end

  describe 'can handle expirations' do
    before do
      Timecop.freeze(Time.zone.now)
    end

    after do
      Timecop.return
    end

    it 'sets a default expiration of 24 hours' do
      token = Api::Jwt.encode(subject: 456)

      Timecop.travel(86_401)

      decoded_payload = Api::Jwt.decode(token)

      expect(decoded_payload).not_to be_valid
      expect(decoded_payload.expired).to be true
    end

    it 'can set a not before time' do
      token = Api::Jwt.encode(subject: 789, not_before: 1.minute)

      decoded_payload = Api::Jwt.decode(token)

      expect(decoded_payload).not_to be_valid
      expect(decoded_payload.immature).to be true
    end
  end
end
