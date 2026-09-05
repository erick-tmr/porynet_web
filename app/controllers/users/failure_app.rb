module Users
  class FailureApp < Devise::FailureApp
    protected

    # Devise reads warden_options[:locale], which nothing sets on an authenticate_user! bounce, so
    # the "sign in first" alert would come back in English for a reader who is on /pt.
    def i18n_locale
      super || locale_param
    end

    # Devise builds this URL from the parent controller's class-level default_url_options, and ours
    # is an instance method, so the locale segment would be dropped and a /pt reader would land on
    # the English /login.
    def scope_url
      return super if locale_param.blank?

      new_user_session_url(locale: locale_param, script_name: nil)
    end

    def locale_param
      request.path_parameters[:locale]
    end
  end
end
