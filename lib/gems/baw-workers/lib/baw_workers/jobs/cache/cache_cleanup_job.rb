# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Cache
      # Runs periodically to:
      # 1. Collect and store statistics about the media caches (audio, spectrogram, etc.)
      # 2. Clean up cache files that exceed the maximum size or minimum age constraints
      #
      # Configuration is driven by `Settings.actions.cache_cleanup` with per-cache overrides
      # available via `SiteSettings`.
      class CacheCleanupJob < BawWorkers::Jobs::ApplicationJob
        HISTOGRAM_BUCKETS = 100

        queue_as Settings.actions.cache_cleanup.queue

        perform_expects # no arguments

        recurring_at Settings.actions.cache_cleanup.schedule

        # Only allow one of these to run at once to avoid concurrent filesystem operations.
        limit_concurrency_to 1, on_limit: :discard

        def perform
          results = []

          results << process_cache(
            :audio,
            BawWorkers::Config.audio_cache_helper,
            SiteSettings.audio_cache_cleanup_enabled
          )

          results << process_cache(
            :spectrogram,
            BawWorkers::Config.spectrogram_cache_helper,
            SiteSettings.spectrogram_cache_cleanup_enabled
          )

          results.compact
        end

        def create_job_id
          ::BawWorkers::ActiveJob::Identity::Generators.generate_timestamp(self)
        end

        def name
          'CacheCleanupJob'
        end

        private

        # Process a single cache: collect stats and optionally clean up.
        # @param [Symbol] cache_name the name of the cache (:audio, :spectrogram)
        # @param [BawWorkers::Storage::Common] cache_helper the storage helper
        # @param [Boolean, nil] site_setting_enabled override from database site setting
        # @return [Statistics::CacheStatistics] the generated statistics record
        def process_cache(cache_name, cache_helper, site_setting_enabled)
          cache_config = Settings.actions.cache_cleanup.public_send(cache_name)
          # site setting overrides config file; fall back to config file value
          enabled = site_setting_enabled.nil? ? cache_config.enabled : site_setting_enabled

          logger.info("Processing cache: #{cache_name}, enabled: #{enabled}")

          file_sizes = collect_file_sizes(cache_helper)

          stats = build_statistics(cache_name.to_s, file_sizes)
          stats.save!

          logger.info(
            "Cache statistics saved for #{cache_name}",
            size_bytes: stats.size_bytes,
            item_count: stats.item_count
          )

          if enabled
            max_size_bytes = cache_config.max_size_bytes
            min_age_seconds = Settings.actions.cache_cleanup.min_age_seconds
            deleted_count = cleanup_cache(cache_helper, file_sizes, max_size_bytes, min_age_seconds)
            logger.info("Cleaned up #{deleted_count} files from #{cache_name} cache")
          else
            logger.info("Cache cleanup is disabled for #{cache_name}, skipping")
          end

          stats
        rescue StandardError => e
          logger.error("Failed to process cache #{cache_name}", exception: e)
          nil
        end

        # Collect sizes and mtimes for all files in the cache.
        # @param [BawWorkers::Storage::Common] cache_helper
        # @return [Array<Hash>] array of { path:, size:, mtime: }
        def collect_file_sizes(cache_helper)
          files = []
          cache_helper.existing_files do |path|
            stat = File.stat(path)
            files << { path: path, size: stat.size, mtime: stat.mtime }
          rescue Errno::ENOENT
            # file may have been deleted between listing and stat
          end
          files
        end

        # Build a Statistics::CacheStatistics record from the collected file data.
        # @param [String] cache_name
        # @param [Array<Hash>] file_sizes
        # @return [Statistics::CacheStatistics]
        def build_statistics(cache_name, file_sizes)
          sizes = file_sizes.map { |f| f[:size] }
          total_size = sizes.sum
          item_count = sizes.count

          min_size, max_size, mean_size, std_dev_size = compute_size_stats(sizes)
          histogram = compute_histogram(sizes, min_size, max_size)

          Statistics::CacheStatistics.new(
            name: cache_name,
            size_bytes: total_size,
            item_count: item_count,
            min_item_size: min_size,
            max_item_size: max_size,
            mean_item_size: mean_size,
            std_dev_item_size: std_dev_size,
            histogram: histogram,
            generated_at: Time.zone.now
          )
        end

        # Compute min, max, mean, and standard deviation of file sizes.
        # @param [Array<Integer>] sizes
        # @return [Array<Integer, Integer, Float, Float>]
        def compute_size_stats(sizes)
          return [nil, nil, nil, nil] if sizes.empty?

          min_size = sizes.min
          max_size = sizes.max
          mean_size = sizes.sum.to_f / sizes.count
          variance = sizes.sum { |s| (s - mean_size)**2 } / sizes.count.to_f
          std_dev_size = Math.sqrt(variance)

          [min_size, max_size, mean_size, std_dev_size]
        end

        # Compute a 100-bucket histogram of file sizes.
        # @param [Array<Integer>] sizes
        # @param [Integer, nil] min_size
        # @param [Integer, nil] max_size
        # @return [Array<Hash>, nil]
        def compute_histogram(sizes, min_size, max_size)
          return nil if sizes.empty? || min_size.nil? || max_size.nil?
          return nil if min_size == max_size

          range = max_size - min_size
          bucket_width = range.to_f / HISTOGRAM_BUCKETS

          buckets = Array.new(HISTOGRAM_BUCKETS, 0)
          sizes.each do |size|
            bucket_index = [(((size - min_size) / bucket_width)).floor, HISTOGRAM_BUCKETS - 1].min
            buckets[bucket_index] += 1
          end

          buckets.map.with_index { |count, i|
            {
              lower: min_size + (i * bucket_width),
              upper: min_size + ((i + 1) * bucket_width),
              count: count
            }
          }
        end

        # Delete files from the cache that exceed the max size, oldest first.
        # Only deletes files older than min_age_seconds.
        # @param [BawWorkers::Storage::Common] cache_helper
        # @param [Array<Hash>] file_sizes
        # @param [Integer] max_size_bytes
        # @param [Integer] min_age_seconds
        # @return [Integer] number of files deleted
        def cleanup_cache(cache_helper, file_sizes, max_size_bytes, min_age_seconds)
          total_size = file_sizes.sum { |f| f[:size] }
          return 0 if total_size <= max_size_bytes

          cutoff_time = Time.zone.now - min_age_seconds

          # Only consider files that are old enough to delete
          eligible_files = file_sizes
            .select { |f| f[:mtime] < cutoff_time }
            .sort_by { |f| f[:mtime] } # oldest first

          deleted_count = 0

          eligible_files.each do |file_info|
            break if total_size <= max_size_bytes

            begin
              File.delete(file_info[:path])
              total_size -= file_info[:size]
              deleted_count += 1
            rescue Errno::ENOENT
              # already deleted, adjust size and continue
              total_size -= file_info[:size]
            rescue StandardError => e
              logger.warn("Could not delete cache file #{file_info[:path]}", exception: e)
            end
          end

          deleted_count
        end
      end
    end
  end
end
