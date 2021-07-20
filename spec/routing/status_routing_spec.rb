# frozen_string_literal: true

describe StatusController, type: :routing do
  it { expect(get('/status')).to route_to('status#index', format: 'json') }
  it { expect(get('/status.json')).to route_to('status#index', format: 'json') }
end
