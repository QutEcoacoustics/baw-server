# frozen_string_literal: true

describe BawWorkers::Jobs::Cache::CacheCleanupJob do
  pause_all_jobs

  before do
    clear_pending_jobs
  end

  let(:queue_name) { Settings.actions.cache_cleanup.queue }

  context 'when checking basic job behaviour' do
    it 'works on the maintenance queue' do
      expect(BawWorkers::Jobs::Cache::CacheCleanupJob.queue_name).to eq(queue_name)
    end

    it 'can be enqueued' do
      BawWorkers::Jobs::Cache::CacheCleanupJob.perform_later

      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Cache::CacheCleanupJob)

      clear_pending_jobs
    end

    it 'has a sensible name' do
      job = BawWorkers::Jobs::Cache::CacheCleanupJob.new
      expect(job.name).to eq('CacheCleanupJob')
    end

    it 'has a recurring schedule' do
      expect(BawWorkers::Jobs::Cache::CacheCleanupJob.recurring_cron_schedule).to be_present
    end
  end

  context 'when collecting statistics' do
    let(:audio_cache_helper) { BawWorkers::Config.audio_cache_helper }
    let(:spectrogram_cache_helper) { BawWorkers::Config.spectrogram_cache_helper }

    let(:fake_files) {
      [
        { path: '/tmp/cache/file1.mp3', size: 1024, mtime: 2.days.ago },
        { path: '/tmp/cache/file2.mp3', size: 2048, mtime: 3.days.ago },
        { path: '/tmp/cache/file3.mp3', size: 4096, mtime: 1.day.ago }
      ]
    }

    before do
      allow(audio_cache_helper).to receive(:existing_files) do |&block|
        fake_files.each { |f| block.call(f[:path]) }
      end
      allow(spectrogram_cache_helper).to receive(:existing_files) do |&block|
        fake_files.each { |f| block.call(f[:path]) }
      end
      fake_files.each do |file_info|
        stat = instance_double(File::Stat, size: file_info[:size], mtime: file_info[:mtime])
        allow(File).to receive(:stat).with(file_info[:path]).and_return(stat)
      end
    end

    it 'creates Statistics::CacheStatistics records after running' do
      expect {
        BawWorkers::Jobs::Cache::CacheCleanupJob.perform_now
      }.to change(Statistics::CacheStatistics, :count).by(2)
    end

    it 'records correct aggregate statistics' do
      BawWorkers::Jobs::Cache::CacheCleanupJob.perform_now

      audio_stat = Statistics::CacheStatistics.find_by(name: 'audio')
      expect(audio_stat).to have_attributes(
        size_bytes: 7168, # 1024 + 2048 + 4096
        item_count: 3,
        min_item_size: 1024,
        max_item_size: 4096
      )
      expect(audio_stat.mean_item_size.to_f).to be_within(1).of(7168.0 / 3)
    end
  end

  context 'when cleaning up caches' do
    let(:audio_cache_helper) { BawWorkers::Config.audio_cache_helper }

    let(:large_old_files) {
      [
        { path: '/tmp/cache/old1.mp3', size: 5_000_000_000, mtime: 2.days.ago }, # 5 GB, old
        { path: '/tmp/cache/old2.mp3', size: 5_000_000_000, mtime: 3.days.ago }  # 5 GB, old
      ]
    }

    before do
      SiteSettings.audio_cache_cleanup_enabled = true
      SiteSettings.spectrogram_cache_cleanup_enabled = false

      allow(audio_cache_helper).to receive(:existing_files) do |&block|
        large_old_files.each { |f| block.call(f[:path]) }
      end
      allow(BawWorkers::Config.spectrogram_cache_helper).to receive(:existing_files) do |&block|
        # empty spectrogram cache
      end

      large_old_files.each do |file_info|
        stat = instance_double(File::Stat, size: file_info[:size], mtime: file_info[:mtime])
        allow(File).to receive(:stat).with(file_info[:path]).and_return(stat)
      end

      allow(File).to receive(:delete)
    end

    after do
      SiteSettings.reset_all_settings!
    end

    it 'deletes old files when total size exceeds max_size_bytes' do
      BawWorkers::Jobs::Cache::CacheCleanupJob.perform_now

      # Both files are 10 GB total, max is 10 GB (default), so at least one should be deleted
      # oldest file is old2.mp3 at 3 days ago
      expect(File).to have_received(:delete).at_least(:once)
    end

    it 'does not delete files from disabled caches' do
      spectrogram_cache_helper = BawWorkers::Config.spectrogram_cache_helper
      allow(spectrogram_cache_helper).to receive(:existing_files) do |&block|
        large_old_files.each { |f| block.call(f[:path]) }
      end

      BawWorkers::Jobs::Cache::CacheCleanupJob.perform_now

      # Spectrogram cleanup is disabled, so no files from spectrogram cache should be deleted
      # Only audio cache files can be deleted
      expect(File).not_to have_received(:delete).with('/tmp/cache/old2.mp3')
    end
  end
end
