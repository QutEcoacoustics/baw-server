# frozen_string_literal: true

require 'workers_helper'

describe 'test worker' do
  it 'checks our test worker is monitoring all known queues' do
    expect(Settings.resque.queues_to_process).to match_array Settings.actions.each.map { |_k, v| v.queue }.to_a
  end
end
