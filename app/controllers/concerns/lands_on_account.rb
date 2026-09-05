module LandsOnAccount
  extend ActiveSupport::Concern

  private

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || account_path(locale: params[:locale])
  end
end
