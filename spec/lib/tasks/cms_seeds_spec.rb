# frozen_string_literal: true

require 'rails_helper'
require(Rails.root / 'spec' / 'helpers' / 'shared-context' / 'rake_context')

describe 'baw:import_cms' do
  include_context 'rake_spec_context'

  its(:prerequisites) { should include('db:seed') }
end

describe 'db:seed' do
  include_context 'rake_spec_context'

  its(:actions) { should have_at_least(2).items }

  # we can't actually test that the action is the one we expect
  # best we can do is check which file the proc came from
  it 'one of the actions runs code from the cms_seeds.rb file' do
    target_proc = subject.actions[1]
    source_path = target_proc.source_location[0]
    expect(source_path).to end_with('/lib/tasks/cms_seed.rake')
  end
end
