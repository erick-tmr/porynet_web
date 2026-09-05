module Users
  class RegistrationsController < Devise::RegistrationsController
    include LandsOnAccount

    protected

    def sign_up_params
      params.expect(user: [ :trainer_name, :email, :password, :password_confirmation,
                           :avatar, :terms ])
    end

    def after_inactive_sign_up_path_for(resource)
      new_user_confirmation_path(email: resource.email)
    end
  end
end
