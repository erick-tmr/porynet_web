module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    include OauthStash

    ON_SECURITY = %i[linked taken already_connected].freeze

    # The authorize path never reaches Rails (the OmniAuth middleware answers it), so the
    # callback is the only action here worth throttling.
    rate_limit to: 10, within: 3.minutes, only: :google_oauth2, store: RATE_LIMIT_STORE

    def google_oauth2 = settle(OmniauthLinker.new(request.env["omniauth.auth"], current_user))

    def failure
      redirect_to new_user_session_path, alert: t("devise.omniauth_callbacks.failure_generic")
    end

    protected

    # LandsOnAccount reads the locale off params, and this route has no :locale segment.
    # I18n.locale is already set from omniauth.params, so default_url_options carries it.
    def after_sign_in_path_for(resource)
      stored_location_for(resource) || account_path
    end

    private

    def settle(linker)
      result = linker.call
      return sign_in_and_land(result) if result.status == :signed_in
      return stash_and_ask(linker, result) if result.status == :signup

      redirect_to landing_for(result), flash_for(result)
    end

    def sign_in_and_land(result)
      clear_oauth_stash
      sign_in_and_redirect result.user, event: :authentication
    end

    def stash_and_ask(linker, result)
      stash_oauth(linker.credentials)
      redirect_to new_user_omniauth_registration_path,
                  notice: t("account.oauth.almost", email: result.email)
    end

    def landing_for(result)
      ON_SECURITY.include?(result.status) ? account_security_path : new_user_session_path
    end

    def flash_for(result)
      copy = t("account.oauth.#{result.status}", email: result.email,
                                                 provider: t("account.oauth.#{result.provider}"))
      result.status == :linked ? { notice: copy } : { alert: copy }
    end

    # The callback lives outside the locale scope, so params carry no :locale. OmniAuth hands
    # back the authorize request's query string, which is where default_url_options put it.
    def switch_locale(&action)
      I18n.with_locale(requested_locale, &action)
    end

    def requested_locale
      wanted = request.env["omniauth.params"].to_h["locale"].to_s
      I18n.available_locales.map(&:to_s).include?(wanted) ? wanted : I18n.default_locale
    end
  end
end
