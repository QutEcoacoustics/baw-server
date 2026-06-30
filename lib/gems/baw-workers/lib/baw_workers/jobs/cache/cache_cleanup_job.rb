# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Cache
      # Runs for one cache type (audio or spectrogram) to:
      # 1. Collect and store statistics about the cache
      # 2. Clean up cache files according to configured conditions:
      #    - Age-based: delete files older than +minimum_age_seconds+ (if configured)
      #    - Size-based: delete oldest files until cache is under +max_size_bytes+ (if configured)
      #
      # Both cleanup conditions are independent and each is optional.
      # Configuration is in +Settings.actions.cache_cleanup.<cache_name>+.
      # Enable/disable is controlled per-cache via +SiteSettings+.
      class CacheCleanupJob < BawWorkers::Jobs::ApplicationJob
        HISTOGRAM_BUCKETS = 100

        # Represents a single scanned file.
        # @!attribute [r] path [String] absolute path to the file
        # @!attribute [r] size [Integer] file size in bytes
        # @!attribute [r] mtime [Time] file modification time
        FileInfo = ::Data.define(:path, :size, :mtime)

        queue_as Settings.actions.cache_cleanup.queue

        perform_expects String

        def perform(cache_name)
          cache_config = Settings.actions.cache_cleanup.public_send(cache_name)

          enabled = SiteSettings.public_send(:"#{cache_name}_cache_cleanup_enabled")
          cache_helper = BawWorkers::Config.public_send(:"#{cache_name}_cache_helper")

          max_size_bytes = cache_config.max_size_bytes
          minimum_age_seconds = cache_config.minimum_age_seconds

          push_message("Processing #{cache_name} cache (enabled: #{enabled})")

          # always collect stats, regardless of enabled flag
          pre_stats = logger.measure_info("#{cache_name} cache statistics collected") {
            collect_and_save_stats(cache_name, cache_helper)
          }

          push_message(
            "#{cache_name} cache: #{pre_stats.item_count} files, " \
            "#{pre_stats.total_bytes} bytes total"
          )

          if enabled
            deleted_count, deleted_bytes = logger.measure_info(
              "#{cache_name} cache cleanup complete"
            ) {
              cleanup_cache(pre_stats.files, max_size_bytes, minimum_age_seconds)
            }

            push_message("#{cache_name}: deleted #{deleted_count} files (#{deleted_bytes} bytes)")

            if deleted_count.positive?
              # save updated stats post-cleanup
              logger.measure_info("#{cache_name} cache post-cleanup statistics collected") {
                collect_and_save_stats(cache_name, cache_helper)
              }
            end
          else
            push_message("Cleanup disabled for #{cache_name}, skipping")
          end

          completed!("Finished #{cache_name} cache cleanup")
        end

        def create_job_id
          ::BawWorkers::ActiveJob::Identity::Generators.generate_keyed_id(
            self,
            { cache: arguments[0] },
            'CacheCleanupJob'
          )
        end

        def name
          "CacheCleanupJob:#{arguments.first}"
        end

        private

        # Collects file statistics from the cache and persists a CacheStatistics record.
        # Also stores the scanned file list on the record for use by cleanup.
        # @param cache_name [String]
        # @param cache_helper [BawWorkers::Storage::Common]
        # @return [::Statistics::CacheStatistics] the saved record (with +files+ attribute attached)
        def collect_and_save_stats(cache_name, cache_helper)
          # Scan files and build incremental stats in one pass using Welford's online algorithm
          files = []
          item_count = 0
          total_bytes = 0
          minimum_bytes = nil
          maximum_bytes = nil
          mean = 0.0
          m2 = 0.0 # second moment for variance (Welford)

          cache_helper.existing_files do |path|
            stat = File.stat(path)
            size = stat.size
            mtime = stat.mtime

            files << FileInfo.new(path:, size:, mtime:)

            item_count += 1
            total_bytes += size
            minimum_bytes = minimum_bytes.nil? ? size : [minimum_bytes, size].min
            maximum_bytes = maximum_bytes.nil? ? size : [maximum_bytes, size].max

            # Welford's online mean/variance
            delta = size - mean
            mean += delta / item_count
            m2 += delta * (size - mean)

            # report progress periodically to avoid flooding Redis
            push_message("Scanned #{item_count} files...") if (item_count % 10_000).zero?
          rescue Errno::ENOENT
            # file may have been deleted between listing and stat, skip
          end

          mean_bytes, std_dev_bytes =
            if item_count.positive?
              variance = item_count > 1 ? m2 / item_count : 0.0
              [mean, Math.sqrt(variance)]
            else
              [nil, nil]
            end

          report_progress(item_count, item_count, "Scan complete: #{item_count} files, #{total_bytes} bytes")

          histogram = build_histogram(files.map(&:size), minimum_bytes, maximum_bytes)

          record = ::Statistics::CacheStatistics.create!(
            name: cache_name,
            total_bytes:,
            item_count:,
            minimum_bytes:,
            maximum_bytes:,
            mean_bytes:,
            standard_deviation_bytes: std_dev_bytes,
            size_histogram: histogram
          )

          # Attach file list for use by cleanup (not persisted)
          record.define_singleton_method(:files) { files }

          record
        end

        # Build a 100-bucket histogram using +bucket+ as a two-element [lower, upper] tuple.
        # Returns nil for empty or uniform-size caches.
        # @param sizes [Array<Integer>]
        # @param minimum_bytes [Integer, nil]
        # @param maximum_bytes [Integer, nil]
        # @return [Array<Hash>, nil]
        def build_histogram(sizes, minimum_bytes, maximum_bytes)
          return nil if sizes.empty? || minimum_bytes.nil? || maximum_bytes.nil?
          return nil if minimum_bytes == maximum_bytes

          range = maximum_bytes - minimum_bytes
          bucket_width = range.to_f / HISTOGRAM_BUCKETS

          counts = Array.new(HISTOGRAM_BUCKETS, 0)
          sizes.each do |size|
            index = [((size - minimum_bytes) / bucket_width).floor, HISTOGRAM_BUCKETS - 1].min
            counts[index] += 1
          end

          counts.map.with_index { |count, i|
            {
              bucket: [minimum_bytes + (i * bucket_width), minimum_bytes + ((i + 1) * bucket_width)],
              count:
            }
          }
        end

        # Delete cache files according to the configured conditions.
        # Both conditions are independent:
        # - Age condition: delete any file older than +minimum_age_seconds+
        # - Size condition: delete oldest files until under +max_size_bytes+
        #
        # @param files [Array<FileInfo>]
        # @param max_size_bytes [Integer, nil] nil disables size-based cleanup
        # @param minimum_age_seconds [Integer, nil] nil disables age-based cleanup
        # @return [Array(Integer, Integer)] [deleted_count, deleted_bytes]
        def cleanup_cache(files, max_size_bytes, minimum_age_seconds)
          return [0, 0] if files.empty?

          cutoff_time = minimum_age_seconds ? (Time.zone.now - minimum_age_seconds.seconds) : nil
          remaining_bytes = files.sum(&:size)

          deleted_count = 0
          deleted_bytes = 0

          files.sort_by(&:mtime).each do |fi|
            age_eligible = cutoff_time && fi.mtime < cutoff_time
            size_eligible = max_size_bytes && remaining_bytes > max_size_bytes

            next unless age_eligible || size_eligible

            begin
              File.delete(fi.path)
              deleted_count += 1
              deleted_bytes += fi.size
              remaining_bytes -= fi.size
            rescue Errno::ENOENT
              # already deleted; still adjust running total
              remaining_bytes -= fi.size
            rescue StandardError => e
              logger.warn("Could not delete cache file #{fi.path}", exception: e)
            end
          end

          [deleted_count, deleted_bytes]
        end
      end

      # Scheduled job for the audio cache.
      class AudioCacheCleanupJob < CacheCleanupJob
        recurring_at Settings.actions.cache_cleanup.audio.schedule, args: ['audio']
      end

      # Scheduled job for the spectrogram cache.
      class SpectrogramCacheCleanupJob < CacheCleanupJob
        recurring_at Settings.actions.cache_cleanup.spectrogram.schedule, args: ['spectrogram']
      end
    end
  end
end
