# `rate_limit` captures its store when the class body runs, which in the test environment is the
# null store, so the limiter would be permanently inert and untestable. Forwarding to Rails.cache
# per call keeps production on Solid Cache and lets a test swap in a real store.
module RateLimitStore
  def self.increment(key, amount = 1, **options)
    Rails.cache.increment(key, amount, **options)
  end
end
