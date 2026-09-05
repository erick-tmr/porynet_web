# frozen_string_literal: true

RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new(size: 2.megabytes)
