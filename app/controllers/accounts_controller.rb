class AccountsController < ApplicationController
  before_action :authenticate_user!

  rate_limit to: 5, within: 1.hour, only: :update_email, store: RATE_LIMIT_STORE

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
    blank_forms
  end

  def update_email
    @email_form = reloaded_user
    if @email_form.update_with_password(email_params)
      redirect_to account_security_path, **email_flash(@email_form)
    else
      render_security
    end
  end

  def update_password
    @password_form = reloaded_user
    if password_params[:password].blank?
      @password_form.errors.add(:password, :blank)
      render_security
    elsif @password_form.update_with_password(password_params)
      bypass_sign_in(@password_form)
      redirect_to account_security_path, notice: t("account.security.password_saved")
    else
      render_security
    end
  end

  def save_file
  end

  private

  def avatar_params = params.expect(account_avatar: [ :avatar ])

  # The picker's filters ride along so saving puts the trainer back where they were looking.
  def picker_params = params.permit(:gen, :q, :page).to_h.compact_blank

  def current_avatar_name = AccountData.avatar(current_user.avatar).name

  def email_params
    params.expect(account_email: [ :email, :email_confirmation, :current_password ])
  end

  def password_params
    params.expect(account_password: [ :current_password, :password, :password_confirmation ])
  end

  def email_flash(user)
    return { alert: t("account.security.email_unchanged") } unless user.pending_reconfirmation?

    { notice: t("account.security.email_sent", email: user.unconfirmed_email) }
  end

  def reloaded_user = User.find(current_user.id)

  def blank_forms
    @email_form ||= User.new
    @password_form ||= User.new
  end

  def render_security
    blank_forms
    render :security, status: :unprocessable_entity
  end
end
