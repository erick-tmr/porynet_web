require "test_helper"

class AccountSecurityTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  PASSWORD = "pikachu123".freeze
  NEW_PASSWORD = "onix-rules-9".freeze
  NEW_EMAIL = "ash@viridian.city".freeze

  setup { sign_in users(:confirmed) }

  test "a new address is only pending until the link in the mail is followed" do
    assert_difference "ActionMailer::Base.deliveries.size", 2 do
      patch account_security_email_path, params: { account_email: email_params }
    end

    trainer = users(:confirmed).reload

    assert_redirected_to account_security_path
    assert_equal I18n.t("account.security.email_sent", email: NEW_EMAIL), flash[:notice]
    assert_equal "ash@pallet.town", trainer.email
    assert_equal NEW_EMAIL, trainer.unconfirmed_email
    assert_equal [ [ "ash@pallet.town" ], [ NEW_EMAIL ] ],
                 ActionMailer::Base.deliveries.last(2).map(&:to)

    get user_confirmation_path(confirmation_token: raw_confirmation_token)

    assert_redirected_to account_security_path
    assert_equal I18n.t("devise.confirmations.email_changed"), flash[:notice]
    assert_equal NEW_EMAIL, trainer.reload.email
    assert_nil trainer.unconfirmed_email
  end

  test "the page names the address still waiting and offers the mail again" do
    patch account_security_email_path, params: { account_email: email_params }
    get account_security_path

    assert_select ".pn-account__current--pending .pn-account__current-value", text: NEW_EMAIL
    assert_select "a[href=?]", new_user_confirmation_path(email: "ash@pallet.town")
  end

  test "the wrong current password mails nobody and leaves the address alone" do
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      patch account_security_email_path,
            params: { account_email: email_params.merge(current_password: "wrong-one") }
    end

    assert_response :unprocessable_content
    assert_nil users(:confirmed).reload.unconfirmed_email
    assert_select ".pn-account__current-value", text: "ash@pallet.town"
  end

  test "a failed email change leaves the password panel clean" do
    patch account_security_email_path,
          params: { account_email: email_params.merge(current_password: "wrong-one") }

    assert_select ".pn-field__error", count: 1,
                  text: /#{I18n.t("errors.messages.invalid")}/
  end

  test "a confirmation that does not match the new address is refused" do
    patch account_security_email_path,
          params: { account_email: email_params.merge(email_confirmation: "ash@celadon.city") }

    assert_response :unprocessable_content
    assert_nil users(:confirmed).reload.unconfirmed_email
    assert_select ".pn-field__error", count: 1
  end

  test "sending the address already on the save file says so instead of promising a link" do
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      patch account_security_email_path,
            params: { account_email: email_params.merge(email: "ash@pallet.town",
                                                        email_confirmation: "ash@pallet.town") }
    end

    assert_redirected_to account_security_path
    assert_equal I18n.t("account.security.email_unchanged"), flash[:alert]
  end

  test "a new password takes over without logging this browser out" do
    patch account_security_password_path, params: { account_password: password_params }

    assert_redirected_to account_security_path
    assert_equal I18n.t("account.security.password_saved"), flash[:notice]
    assert users(:confirmed).reload.valid_password?(NEW_PASSWORD)

    get account_path

    assert_response :success

    delete destroy_user_session_path
    post user_session_path, params: { user: { login: "ASH", password: NEW_PASSWORD } }

    assert_redirected_to account_path
  end

  test "the wrong current password keeps the old one" do
    patch account_security_password_path,
          params: { account_password: password_params.merge(current_password: "wrong-one") }

    assert_response :unprocessable_content
    assert users(:confirmed).reload.valid_password?(PASSWORD)
    assert_select ".pn-field__error", count: 1
  end

  test "a confirmation that does not match the new password is refused" do
    patch account_security_password_path,
          params: { account_password: password_params.merge(password_confirmation: "onix-rules-8") }

    assert_response :unprocessable_content
    assert users(:confirmed).reload.valid_password?(PASSWORD)
    assert_select ".pn-field__error", count: 1
  end

  test "an empty new password is refused rather than reported as saved" do
    patch account_security_password_path,
          params: { account_password: password_params.merge(password: "", password_confirmation: "") }

    assert_response :unprocessable_content
    assert users(:confirmed).reload.valid_password?(PASSWORD)
    assert_select ".pn-field__error", text: /#{I18n.t("errors.messages.blank")}/
  end

  test "a guest can change neither the address nor the password" do
    sign_out users(:confirmed)

    patch account_security_email_path, params: { account_email: email_params }

    assert_redirected_to new_user_session_path

    patch account_security_password_path, params: { account_password: password_params }

    assert_redirected_to new_user_session_path
  end

  test "the Portuguese page saves a new password and answers in Portuguese" do
    patch "/pt/account/security/password", params: { account_password: password_params }

    assert_redirected_to "/pt/account/security"
    assert_equal I18n.t("account.security.password_saved", locale: :pt), flash[:notice]
  end

  private

  def email_params
    { email: NEW_EMAIL, email_confirmation: NEW_EMAIL, current_password: PASSWORD }
  end

  def password_params
    { current_password: PASSWORD, password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
  end

  def raw_confirmation_token
    ActionMailer::Base.deliveries.last.body.to_s[/confirmation_token=([^"&\s]+)/, 1]
  end
end
