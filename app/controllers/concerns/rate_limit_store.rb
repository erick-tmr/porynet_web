module RateLimitStore
  def self.increment(key, amount = 1, **options)
    Rails.cache.increment(key, amount, **options)
  end
end
