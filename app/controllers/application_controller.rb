# Rails 8 enables CSRF protection by default, so protect_from_forgery is redundant.
# nosemgrep: ruby.lang.security.missing-csrf-protection.missing-csrf-protection
class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :switch_locale

  private

  def switch_locale(&action)
    I18n.with_locale(params[:locale] || I18n.default_locale, &action)
  end

  def default_url_options
    { locale: (I18n.locale unless I18n.locale == I18n.default_locale) }
  end
end
