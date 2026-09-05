module Users
  class PasswordsController < Devise::PasswordsController
    include LandsOnAccount

    rate_limit to: 5, within: 1.hour, only: :create, store: RateLimitStore
  end
end
