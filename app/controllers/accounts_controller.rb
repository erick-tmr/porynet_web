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
    if save_email(@email_form)
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
    elsif save_password(@password_form)
      bypass_sign_in(@password_form)
      redirect_to account_security_path, notice: t("account.security.password_saved")
    else
      render_security
    end
  end

  def disconnect_identity
    identity = current_user.identities.find_by!(provider: params[:provider])
    redirect_to account_security_path, **disconnect(identity)
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

  def disconnect(identity)
    return { alert: t("account.security.sole_way_in") } if current_user.sole_way_in?

    identity.destroy
    { notice: t("account.security.disconnected",
                provider: t("account.oauth.#{identity.provider}")) }
  end

  # An account that signed up through a provider has no password to be asked for, on either form.
  def save_email(user)
    return user.update_with_password(email_params) if user.password_set?

    user.update(email_params.except(:current_password))
  end

  def save_password(user)
    return user.update_with_password(password_params) if user.password_set?

    user.update(password_params.except(:current_password))
  end

  def blank_forms
    @email_form ||= User.new
    @password_form ||= User.new
  end

  def render_security
    blank_forms
    render :security, status: :unprocessable_entity
  end
end
