module Users
  class Mailer < Devise::Mailer
    helper_method :mail_locale

    private

    # The confirmation and reset links are built outside a request, so ApplicationController's
    # default_url_options is not in play and a reader who registered on /pt would be sent to the
    # English page.
    def mail_locale
      I18n.locale unless I18n.locale == I18n.default_locale
    end
  end
end
