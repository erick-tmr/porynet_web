class WalkthroughProgressController < ApplicationController
  before_action :authenticate_user!

  rate_limit to: 600, within: 1.hour, store: RATE_LIMIT_STORE

  def update
    return head :unprocessable_content if oversized?

    Progress::Sync.apply(SaveFile.for(current_user, params[:game]),
                         marks: offered(:marks), bodies: offered(:bodies))
    head :no_content
  end

  private

  def oversized?
    [ offered(:marks), offered(:bodies) ].any? { |some| some.size > Progress::Sync::MAX_KEYS }
  end

  def offered(key)
    value = params[key]
    value.is_a?(ActionController::Parameters) ? value.to_unsafe_h : {}
  end
end
