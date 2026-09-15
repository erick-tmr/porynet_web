require "test_helper"

class LinkedLoginsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "the panel offers Google live and the other three still to come" do
    sign_in users(:confirmed)
    get account_security_path

    assert_response :success
    assert_select ".pn-account__social", count: AccountData::OAUTH_PROVIDERS.size
    assert_select "form[action=?]", user_google_oauth2_omniauth_authorize_path
    assert_select ".pn-account__soon", count: AccountData::OAUTH_PROVIDERS.size - 1
  end

  test "a linked provider shows the address it signs in with, and offers to disconnect" do
    sign_in users(:rival)
    get account_security_path

    assert_select ".pn-account__social-state.is-linked", text: I18n.t("account.security.linked")
    assert_select ".pn-account__social-detail", text: "gary@pallet.town"
    assert_select "form[action=?]", account_security_identity_path(provider: "google")
  end

  test "a trainer with a password disconnects a provider" do
    sign_in users(:rival)

    assert_difference "Identity.count", -1 do
      delete account_security_identity_path(provider: "google")
    end

    assert_redirected_to account_security_path
    assert_equal I18n.t("account.security.disconnected", provider: "Google"), flash[:notice]
  end

  test "a trainer whose only way in is the provider cannot disconnect it" do
    sign_in users(:linked)

    assert_no_difference "Identity.count" do
      delete account_security_identity_path(provider: "google")
    end

    assert_redirected_to account_security_path
    assert_equal I18n.t("account.security.sole_way_in"), flash[:alert]
  end

  test "disconnecting a provider that was never linked is a dead end" do
    sign_in users(:confirmed)

    delete account_security_identity_path(provider: "github")

    assert_response :not_found
  end

  test "a trainer with no password is asked to set one, not to confirm the old one" do
    sign_in users(:linked)
    get account_security_path

    assert_select ".pn-account__panel-title", text: I18n.t("account.security.password_title_new")
    assert_select "input[name='account_password[current_password]']", count: 0
  end

  test "a trainer with no password sets their first one and stays signed in" do
    sign_in users(:linked)

    patch account_security_password_path,
          params: { account_password: { password: "onix-rules-9",
                                        password_confirmation: "onix-rules-9" } }

    assert_redirected_to account_security_path
    assert_equal I18n.t("account.security.password_saved"), flash[:notice]
    assert users(:linked).reload.password_set?

    get account_path
    assert_response :success
  end

  test "a trainer with no password is not asked for one to change their address" do
    sign_in users(:linked)
    get account_security_path

    assert_select "input[name='account_email[current_password]']", count: 0
  end

  test "a trainer with no password changes their address, and it is reconfirmed not applied" do
    sign_in users(:linked)
    was = users(:linked).email

    assert_difference "ActionMailer::Base.deliveries.size", 2 do
      patch account_security_email_path,
            params: { account_email: { email: "daisy@viridian.city",
                                       email_confirmation: "daisy@viridian.city" } }
    end

    trainer = users(:linked).reload

    assert_redirected_to account_security_path
    assert_equal was, trainer.email, "the address only moves once the link is followed"
    assert_equal "daisy@viridian.city", trainer.unconfirmed_email
  end

  test "a trainer with a password is still asked for the current one" do
    sign_in users(:confirmed)
    get account_security_path

    assert_select ".pn-account__panel-title", text: I18n.t("account.security.password_title")
    assert_select "input[name='account_password[current_password]']"
    assert_select "input[name='account_email[current_password]']"
  end

  test "the change address button says what it does" do
    sign_in users(:confirmed)
    get account_security_path

    assert_select "input[type=submit][value=?]", I18n.t("account.security.email_submit")
    assert_equal "CHANGE ADDRESS ▶", I18n.t("account.security.email_submit")
  end
end
