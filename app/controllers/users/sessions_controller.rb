module Users
  class SessionsController < Devise::SessionsController
    include LandsOnAccount

    rate_limit to: 10, within: 3.minutes, only: :create, store: RATE_LIMIT_STORE
  end
end
