# reuse redis as our cache store
# Note: potential perf issues as we scale
Rails.application.config.cache_store = :redis_cache_store, {
  redis: Redis.new(Settings.redis.connection.to_h),
  namespace: 'baw-rails-cache',
  expires_in: 3600
}
