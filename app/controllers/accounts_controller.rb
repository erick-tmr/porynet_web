class AccountsController < ApplicationController
  before_action :authenticate_user!

  def show
  end

  def avatar
  end

  def update_avatar
    if current_user.update(avatar_params)
      redirect_to account_avatar_path(picker_params),
                  notice: t("account.avatar.saved", name: current_avatar_name)
    else
      redirect_to account_avatar_path(picker_params), alert: t("account.avatar.rejected")
    end
  end

  def security
  end

  def save_file
  end

  private

  def avatar_params = params.expect(account_avatar: [ :avatar ])

  # The picker's filters ride along so saving puts the trainer back where they were looking.
  def picker_params = params.permit(:gen, :q, :page).to_h.compact_blank

  def current_avatar_name = AccountData.avatar(current_user.avatar).name
end
