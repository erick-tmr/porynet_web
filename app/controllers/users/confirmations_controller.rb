module Users
  class ConfirmationsController < Devise::ConfirmationsController
    include LandsOnAccount

    rate_limit to: 5, within: 1.hour, only: :create, store: RATE_LIMIT_STORE

    def new
      super
      @email = params[:email].presence
    end

    def show
      super
      return unless signed_in?(resource_name) && resource.errors.empty?

      set_flash_message!(:notice, :email_changed)
    end

    protected

    def after_resending_confirmation_instructions_path_for(_resource_name)
      new_user_confirmation_path(email: resource.email)
    end

    def after_confirmation_path_for(resource_name, resource)
      signed_in?(resource_name) ? account_security_path : super
    end
  end
end
