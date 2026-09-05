module Users
  class FailureApp < Devise::FailureApp
    protected

    def i18n_locale
      super || locale_param
    end

    def scope_url
      return super if locale_param.blank?

      new_user_session_url(locale: locale_param, script_name: nil)
    end

    def locale_param
      request.path_parameters[:locale]
    end
  end
end
