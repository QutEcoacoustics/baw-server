# frozen_string_literal: true

require_migration!

describe AddObfuscatedCoordinatesToSites, :migration do
  include ActiveJob::TestHelper

  # We need to test that:
  # 1. The migration adds the new columns
  # 2. The migration enqueues the backfill job after commit

  let(:sites_table) { table(:sites) }
  let(:users_table) { table(:users) }

  ignore_pending_jobs

  before do
    # Create a user for the site's creator_id
    user = users_table.create!(user_name: 'Test User', email: 'test@example.com', encrypted_password: 'password')

    # Create test sites with coordinates
    sites_table.create!(
      id: 1,
      name: 'Site with coordinates',
      latitude: -27.5,
      longitude: 153.0,
      creator_id: user.id
    )

    sites_table.create!(
      id: 2,
      name: 'Site without coordinates',
      latitude: nil,
      longitude: nil,
      creator_id: user.id
    )
  end

  after do
    clear_pending_jobs
  end

  it 'adds obfuscated coordinate columns to sites table' do
    migrate!

    # Refresh the table definition
    sites_table.reset_column_information

    expect(sites_table.column_names).to include('obfuscated_latitude')
    expect(sites_table.column_names).to include('obfuscated_longitude')
    expect(sites_table.column_names).to include('custom_obfuscated_location')
  end

  it 'sets default value for custom_obfuscated_location' do
    migrate!

    sites_table.reset_column_information

    site = sites_table.find(1)
    expect(site.custom_obfuscated_location).to be false
  end

  it 'enqueues the backfill job after migration commits' do
    migrate!

    # The job should have been enqueued
    expect_delayed_jobs(1)
  end
end
