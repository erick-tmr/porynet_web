module Users
  class SessionsController < Devise::SessionsController
    include LandsOnAccount

    # Confirmation is strict and :lockable is off, so this is the only thing between the login form
    # and an unattended password-guessing run.
    rate_limit to: 10, within: 3.minutes, only: :create, store: RateLimitStore
  end
end
