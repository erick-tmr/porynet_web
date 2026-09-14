module Users
  class OmniauthRegistrationsController < ApplicationController
    include LandsOnAccount
    include OauthStash

    before_action :require_pending_oauth

    def new
      @user = User.new(email: @pending["email"])
    end

    def create
      @user = build_trainer
      return render :new, status: :unprocessable_entity unless @user.save

      clear_oauth_stash
      sign_in_and_redirect @user, event: :authentication
    rescue ActiveRecord::RecordNotUnique
      clear_oauth_stash
      redirect_to new_user_session_path,
                  alert: t("account.oauth.taken", provider: t("account.oauth.#{@pending["provider"]}"))
    end

    private

    # Google verified the address, so there is nothing to confirm by mail.
    def build_trainer
      User.new(signup_params.merge(email: @pending["email"])).tap do |user|
        user.skip_confirmation!
        user.identities.build(provider: @pending["provider"], uid: @pending["uid"],
                              email: @pending["email"])
      end
    end

    def signup_params = params.expect(user: [ :trainer_name, :avatar, :terms ])

    def require_pending_oauth
      @pending = pending_oauth
      return if @pending

      clear_oauth_stash
      redirect_to new_user_session_path, alert: t("account.oauth.expired")
    end
  end
end
