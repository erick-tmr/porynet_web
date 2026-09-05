module Users
  class ConfirmationsController < Devise::ConfirmationsController
    include LandsOnAccount

    rate_limit to: 5, within: 1.hour, only: :create, store: RATE_LIMIT_STORE

    def new
      super
      @email = params[:email].presence
    end

    protected

    def after_resending_confirmation_instructions_path_for(_resource_name)
      new_user_confirmation_path(email: resource.email)
    end
  end
end
