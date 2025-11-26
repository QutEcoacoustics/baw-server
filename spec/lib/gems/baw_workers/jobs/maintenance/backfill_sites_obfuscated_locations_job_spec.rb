# frozen_string_literal: true

describe BawWorkers::Jobs::Maintenance::BackfillSitesObfuscatedLocationsJob do
  prepare_users
  prepare_project
  prepare_region

  pause_all_jobs

  before do
    clear_pending_jobs
  end

  let(:queue_name) { Settings.actions.maintenance.queue }

  context 'when checking basic job behaviour' do
    it 'works on the maintenance queue' do
      expect(BawWorkers::Jobs::Maintenance::BackfillSitesObfuscatedLocationsJob.queue_name).to eq(queue_name)
    end

    it 'can enqueue' do
      BawWorkers::Jobs::Maintenance::BackfillSitesObfuscatedLocationsJob.perform_later
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Maintenance::BackfillSitesObfuscatedLocationsJob)

      clear_pending_jobs
    end

    it 'has a sensible name' do
      job = BawWorkers::Jobs::Maintenance::BackfillSitesObfuscatedLocationsJob.new

      expect(job.name).to match(/BackfillSitesObfuscatedLocationsJob:\d+/)
    end
  end

  context 'when backfilling' do
    let!(:site_with_coords) do
      create(:site, :with_lat_long, region:, projects: [project]).tap do |s|
        # Simulate a site that was created before the migration
        s.update_columns(obfuscated_latitude: nil, obfuscated_longitude: nil)
      end
    end

    let!(:site_without_coords) do
      create(:site, region:, projects: [project], latitude: nil, longitude: nil)
    end

    let!(:site_already_backfilled) do
      create(:site, :with_lat_long, region:, projects: [project])
      # This site already has obfuscated coordinates from the factory
    end

    let!(:site_with_custom_obfuscation) do
      create(:site, :with_lat_long, region:, projects: [project]).tap do |s|
        # Simulate a site with user-provided obfuscated location
        s.update_columns(
          obfuscated_latitude: nil,
          obfuscated_longitude: nil,
          custom_obfuscated_location: true
        )
      end
    end

    it 'backfills sites that need obfuscated coordinates' do
      expect(site_with_coords.obfuscated_latitude).to be_nil
      expect(site_with_coords.obfuscated_longitude).to be_nil

      result = BawWorkers::Jobs::Maintenance::BackfillSitesObfuscatedLocationsJob.new.perform

      expect(result).to match hash_including(updated: 1, failed: 0)

      site_with_coords.reload
      expect(site_with_coords.obfuscated_latitude).to be_a(Numeric).and(
        be_within(Site::JITTER_RANGE).of(site_with_coords.latitude)
      )
      expect(site_with_coords.obfuscated_longitude).to be_a(Numeric).and(
        be_within(Site::JITTER_RANGE).of(site_with_coords.longitude)
      )
    end

    it 'does not update sites without coordinates' do
      BawWorkers::Jobs::Maintenance::BackfillSitesObfuscatedLocationsJob.new.perform

      site_without_coords.reload
      expect(site_without_coords.obfuscated_latitude).to be_nil
      expect(site_without_coords.obfuscated_longitude).to be_nil
    end

    it 'does not update sites that already have obfuscated coordinates' do
      original_lat = site_already_backfilled.obfuscated_latitude
      original_lng = site_already_backfilled.obfuscated_longitude

      BawWorkers::Jobs::Maintenance::BackfillSitesObfuscatedLocationsJob.new.perform

      site_already_backfilled.reload
      expect(site_already_backfilled.obfuscated_latitude).to eq(original_lat)
      expect(site_already_backfilled.obfuscated_longitude).to eq(original_lng)
    end

    it 'does not update sites with custom obfuscated locations' do
      BawWorkers::Jobs::Maintenance::BackfillSitesObfuscatedLocationsJob.new.perform

      site_with_custom_obfuscation.reload
      expect(site_with_custom_obfuscation.obfuscated_latitude).to be_nil
      expect(site_with_custom_obfuscation.obfuscated_longitude).to be_nil
    end

    it 'handles partial coordinates (latitude only)' do
      site = create(:site, region:, projects: [project], latitude: -27.5, longitude: nil)
      site.update_columns(obfuscated_latitude: nil)

      BawWorkers::Jobs::Maintenance::BackfillSitesObfuscatedLocationsJob.new.perform

      site.reload
      expect(site.obfuscated_latitude).not_to be_nil
      expect(site.obfuscated_longitude).to be_nil
    end

    it 'handles partial coordinates (longitude only)' do
      site = create(:site, region:, projects: [project], latitude: nil, longitude: 153.0)
      site.update_columns(obfuscated_longitude: nil)

      BawWorkers::Jobs::Maintenance::BackfillSitesObfuscatedLocationsJob.new.perform

      site.reload
      expect(site.obfuscated_latitude).to be_nil
      expect(site.obfuscated_longitude).not_to be_nil
    end

    it 'can be safely re-run' do
      # First run
      result1 = BawWorkers::Jobs::Maintenance::BackfillSitesObfuscatedLocationsJob.new.perform
      expect(result1[:updated]).to eq(1)

      # Second run should update nothing
      result2 = BawWorkers::Jobs::Maintenance::BackfillSitesObfuscatedLocationsJob.new.perform
      expect(result2[:updated]).to eq(0)
    end
  end
end
