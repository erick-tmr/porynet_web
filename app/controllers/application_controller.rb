# Rails 8 enables CSRF protection by default (config.action_controller
# .default_protect_from_forgery = true), so an explicit protect_from_forgery
# call is redundant. Suppress Semgrep's generic controller-CSRF heuristic.
# nosemgrep: ruby.lang.security.missing-csrf-protection.missing-csrf-protection
class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :switch_locale

  private

  # Runs each request under the locale from the URL prefix ("/pt"), or the
  # default when there's no prefix ("/"). The route constraint guarantees any
  # present :locale is one we support.
  def switch_locale(&action)
    I18n.with_locale(params[:locale] || I18n.default_locale, &action)
  end

  # Keeps the active locale in generated URLs so links stay in-language, while
  # omitting the prefix for the default locale to keep "/" clean.
  def default_url_options
    { locale: (I18n.locale unless I18n.locale == I18n.default_locale) }
  end
end
