# frozen_string_literal: true

describe BawWorkers::Jobs::Cache::CacheCleanupJob do
  pause_all_jobs

  before do
    clear_pending_jobs
    SiteSettings.audio_cache_cleanup_enabled = false
    SiteSettings.spectrogram_cache_cleanup_enabled = false
  end

  after do
    SiteSettings.reset_all_settings!
  end

  let(:queue_name) { Settings.actions.cache_cleanup.queue }
  let(:audio_cache_helper) { BawWorkers::Config.audio_cache_helper }
  let(:spectrogram_cache_helper) { BawWorkers::Config.spectrogram_cache_helper }

  context 'when checking basic job behaviour' do
    it 'works on the maintenance queue' do
      expect(BawWorkers::Jobs::Cache::CacheCleanupJob.queue_name).to eq(queue_name)
    end

    it 'can be enqueued with a cache name argument' do
      BawWorkers::Jobs::Cache::CacheCleanupJob.perform_later('audio')

      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Cache::CacheCleanupJob)
      clear_pending_jobs
    end

    it 'generates a deterministic job id from the cache name' do
      job = BawWorkers::Jobs::Cache::CacheCleanupJob.new('audio')
      expect(job.create_job_id).to eq('CacheCleanupJob:cache=audio')
    end

    it 'uses a descriptive job name' do
      job = BawWorkers::Jobs::Cache::CacheCleanupJob.new('audio')
      expect(job.name).to eq('CacheCleanupJob:audio')
    end

    it 'does not allow duplicate audio jobs to be enqueued' do
      # Two enqueues with the same cache name should only produce one job
      BawWorkers::Jobs::Cache::CacheCleanupJob.perform_later('audio')
      BawWorkers::Jobs::Cache::CacheCleanupJob.perform_later('audio')

      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Cache::CacheCleanupJob)
      clear_pending_jobs
    end

    it 'allows audio and spectrogram jobs to coexist' do
      BawWorkers::Jobs::Cache::CacheCleanupJob.perform_later('audio')
      BawWorkers::Jobs::Cache::CacheCleanupJob.perform_later('spectrogram')

      expect_enqueued_jobs(2, of_class: BawWorkers::Jobs::Cache::CacheCleanupJob)
      clear_pending_jobs
    end
  end

  context 'when checking AudioCacheCleanupJob' do
    it 'has a recurring schedule for audio' do
      expect(BawWorkers::Jobs::Cache::AudioCacheCleanupJob.recurring_cron_schedule).to be_present
      expect(BawWorkers::Jobs::Cache::AudioCacheCleanupJob.recurring_cron_schedule_args).to eq(['audio'])
    end
  end

  context 'when checking SpectrogramCacheCleanupJob' do
    it 'has a recurring schedule for spectrogram' do
      expect(BawWorkers::Jobs::Cache::SpectrogramCacheCleanupJob.recurring_cron_schedule).to be_present
      expect(BawWorkers::Jobs::Cache::SpectrogramCacheCleanupJob.recurring_cron_schedule_args).to eq(['spectrogram'])
    end
  end

  context 'when collecting statistics' do
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
        # empty spectrogram cache
      end

      fake_files.each do |file_info|
        stat = instance_double(File::Stat, size: file_info[:size], mtime: file_info[:mtime])
        allow(File).to receive(:stat).with(file_info[:path]).and_return(stat)
      end
    end

    it 'creates a Statistics::CacheStatistics record' do
      expect {
        BawWorkers::Jobs::Cache::CacheCleanupJob.perform_now('audio')
      }.to change(Statistics::CacheStatistics, :count).by(1)
    end

    it 'records correct aggregate statistics' do
      BawWorkers::Jobs::Cache::CacheCleanupJob.perform_now('audio')

      stat = Statistics::CacheStatistics.find_by(name: 'audio')
      expect(stat).to have_attributes(
        total_bytes: 7168, # 1024 + 2048 + 4096
        item_count: 3,
        minimum_bytes: 1024,
        maximum_bytes: 4096
      )
      expect(stat.mean_bytes.to_f).to be_within(1).of(7168.0 / 3)
    end

    it 'does not delete files when cleanup is disabled' do
      allow(File).to receive(:delete)

      BawWorkers::Jobs::Cache::CacheCleanupJob.perform_now('audio')

      expect(File).not_to have_received(:delete)
    end
  end

  context 'when performing age-based cleanup' do
    let(:old_files) {
      [
        { path: '/tmp/cache/old1.mp3', size: 1024, mtime: 10.days.ago },
        { path: '/tmp/cache/old2.mp3', size: 2048, mtime: 8.days.ago }
      ]
    }
    let(:new_files) {
      [
        { path: '/tmp/cache/new1.mp3', size: 1024, mtime: 1.day.ago }
      ]
    }

    before do
      SiteSettings.audio_cache_cleanup_enabled = true

      all_files = old_files + new_files
      allow(audio_cache_helper).to receive(:existing_files) do |&block|
        all_files.each { |f| block.call(f[:path]) }
      end
      allow(spectrogram_cache_helper).to receive(:existing_files) { |&_block| }

      all_files.each do |file_info|
        stat = instance_double(File::Stat, size: file_info[:size], mtime: file_info[:mtime])
        allow(File).to receive(:stat).with(file_info[:path]).and_return(stat)
      end

      allow(File).to receive(:delete)
    end

    it 'deletes files older than minimum_age_seconds' do
      BawWorkers::Jobs::Cache::CacheCleanupJob.perform_now('audio')

      expect(File).to have_received(:delete).with('/tmp/cache/old1.mp3')
      expect(File).to have_received(:delete).with('/tmp/cache/old2.mp3')
    end

    it 'does not delete recently modified files' do
      BawWorkers::Jobs::Cache::CacheCleanupJob.perform_now('audio')

      expect(File).not_to have_received(:delete).with('/tmp/cache/new1.mp3')
    end

    it 'saves a second stats record after deletion' do
      # At start there should be no stats
      expect(Statistics::CacheStatistics.count).to eq(0)

      BawWorkers::Jobs::Cache::CacheCleanupJob.perform_now('audio')

      # Pre-cleanup stats + post-cleanup stats
      expect(Statistics::CacheStatistics.count).to eq(2)
    end
  end

  context 'when performing size-based cleanup' do
    let(:large_old_files) {
      [
        { path: '/tmp/cache/audio_old1.mp3', size: 8_000_000_000, mtime: 5.days.ago }, # 8 GB, old
        { path: '/tmp/cache/audio_old2.mp3', size: 3_000_000_000, mtime: 10.days.ago } # 3 GB, older
      ]
    }

    before do
      SiteSettings.audio_cache_cleanup_enabled = true

      allow(audio_cache_helper).to receive(:existing_files) do |&block|
        large_old_files.each { |f| block.call(f[:path]) }
      end
      allow(spectrogram_cache_helper).to receive(:existing_files) { |&_block| }

      large_old_files.each do |file_info|
        stat = instance_double(File::Stat, size: file_info[:size], mtime: file_info[:mtime])
        allow(File).to receive(:stat).with(file_info[:path]).and_return(stat)
      end

      allow(File).to receive(:delete)
    end

    it 'deletes the oldest files when total exceeds max_size_bytes' do
      # total is 11 GB, max is 10 GB, so must delete at least 1 GB worth
      BawWorkers::Jobs::Cache::CacheCleanupJob.perform_now('audio')

      # oldest file (audio_old2.mp3, 10 days ago) should be deleted first
      expect(File).to have_received(:delete).with('/tmp/cache/audio_old2.mp3')
    end

    it 'does not delete files from a disabled cache' do
      SiteSettings.spectrogram_cache_cleanup_enabled = false
      large_spectrogram_files = [
        { path: '/tmp/cache/spec_old.png', size: 5_000_000_000, mtime: 5.days.ago }
      ]

      allow(spectrogram_cache_helper).to receive(:existing_files) do |&block|
        large_spectrogram_files.each { |f| block.call(f[:path]) }
      end

      large_spectrogram_files.each do |file_info|
        stat = instance_double(File::Stat, size: file_info[:size], mtime: file_info[:mtime])
        allow(File).to receive(:stat).with(file_info[:path]).and_return(stat)
      end

      BawWorkers::Jobs::Cache::CacheCleanupJob.perform_now('spectrogram')

      expect(File).not_to have_received(:delete).with('/tmp/cache/spec_old.png')
    end
  end
end
