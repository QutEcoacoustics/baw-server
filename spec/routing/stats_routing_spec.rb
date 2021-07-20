# frozen_string_literal: true

describe StatsController, type: :routing do
  it { expect(get('/stats')).to route_to('stats#index', format: 'json') }
end
