module Users
  class Mailer < Devise::Mailer
    helper_method :mail_locale

    private

    def mail_locale
      I18n.locale unless I18n.locale == I18n.default_locale
    end
  end
end
