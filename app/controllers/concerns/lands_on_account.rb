module LandsOnAccount
  extend ActiveSupport::Concern

  private

  # Devise prepends require_no_authentication ahead of ApplicationController's around_action, so
  # I18n.locale is still the default when a signed-in reader is turned away from /pt/login. Reading
  # the locale off the request keeps them on the Portuguese side.
  def after_sign_in_path_for(resource)
    stored_location_for(resource) || account_path(locale: params[:locale])
  end
end
