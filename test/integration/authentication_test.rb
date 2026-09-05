require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  PASSWORD = "pikachu123".freeze

  test "the login page offers both tabs, the four providers and no wired provider button" do
    get new_user_session_path

    assert_response :success
    assert_select "a.pn-auth__tab--login.is-active"
    assert_select "a.pn-auth__tab--register[href=?]", new_user_registration_path
    assert_select "input[name='user[login]']"
    assert_select "input[name='user[password]']"
    assert_select "button.pn-auth__provider[disabled]", count: 4
    assert_select "a[href=?]", new_user_password_path
  end

  test "the register page asks for a trainer name, an avatar and the fan-project tick" do
    get new_user_registration_path

    assert_response :success
    assert_select "input[name='user[trainer_name]'][maxlength=?]", "12"
    assert_select "input[name='user[email]']"
    assert_select "input[name='user[password_confirmation]']"
    assert_select "input[name='user[avatar]'][type=radio]", count: 3
    assert_select "input[name='user[avatar]'][value=red][checked]"
    assert_select "input[name='user[terms]'][type=checkbox]"
  end

  test "registering leaves the trainer signed out until the link in the mail is followed" do
    assert_difference [ "User.count", "ActionMailer::Base.deliveries.size" ], 1 do
      post user_registration_path, params: { user: registration_params }
    end

    trainer = User.find_by(trainer_name: "OAK")

    assert_not trainer.confirmed?
    assert_redirected_to new_user_confirmation_path(email: trainer.email)
    assert_nil controller.current_user

    post user_session_path, params: { user: { login: "OAK", password: PASSWORD } }

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("devise.failure.unconfirmed"), flash[:alert]

    get user_confirmation_path(confirmation_token: raw_confirmation_token)

    assert_redirected_to new_user_session_path
    assert_predicate trainer.reload, :confirmed?

    post user_session_path, params: { user: { login: "OAK", password: PASSWORD } }

    assert_redirected_to account_path
  end

  test "registering without the fan-project tick saves nobody" do
    assert_no_difference "User.count" do
      post user_registration_path, params: { user: registration_params.except(:terms) }
    end

    assert_response :unprocessable_content
    assert_select ".pn-form-errors__list li", /#{I18n.t("errors.messages.accepted")}/
  end

  test "a trainer logs in with the name on the save file or with the address" do
    [ "ASH", "ash", "ash@pallet.town", "ASH@PALLET.TOWN" ].each do |login|
      post user_session_path, params: { user: { login: login, password: PASSWORD } }

      assert_redirected_to account_path, "#{login} did not get in"
      delete destroy_user_session_path
    end
  end

  test "the wrong password comes back to the form rather than a redirect" do
    post user_session_path, params: { user: { login: "ASH", password: "wrong-one" } }

    assert_response :unprocessable_content
    assert_equal I18n.t("devise.failure.invalid"), flash[:alert]
    assert_select "input[name='user[login]']"
  end

  test "an empty login form gives nothing away about which half was wrong" do
    post user_session_path, params: { user: { login: "", password: "" } }

    assert_nil controller.current_user
    assert_equal I18n.t("devise.failure.invalid"), flash[:alert]
  end

  test "logging out puts the guest chip back in the header" do
    sign_in users(:confirmed)
    get root_path

    assert_select ".pn-nav__account-name", text: "ASH"

    delete destroy_user_session_path
    follow_redirect!

    assert_select ".pn-nav__account-guest", text: I18n.t("account.chip.guest")
    assert_select "#pn-nav-menu a.pn-nav__menu-link[href=?]", new_user_session_path
  end

  test "a trainer bounced off the account page lands back on it once logged in" do
    get account_path

    assert_redirected_to new_user_session_path

    post user_session_path, params: { user: { login: "ASH", password: PASSWORD } }

    assert_redirected_to account_path
  end

  test "the reset flow mails a link and the link sets a new password" do
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      post user_password_path, params: { user: { email: users(:confirmed).email } }
    end

    assert_equal I18n.t("devise.passwords.send_paranoid_instructions"), flash[:notice]

    get edit_user_password_path(reset_password_token: "raw-reset-token")

    assert_response :success

    put user_password_path, params: { user: { reset_password_token: "raw-reset-token",
                                              password: "onix-rules-9", password_confirmation: "onix-rules-9" } }

    assert_redirected_to account_path
    assert users(:pending_reset).reload.valid_password?("onix-rules-9")
  end

  test "an unknown address is told the same thing as a known one" do
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      post user_password_path, params: { user: { email: "nobody@pallet.town" } }
    end

    assert_equal I18n.t("devise.passwords.send_paranoid_instructions"), flash[:notice]
  end

  test "the confirmation page can send the mail again" do
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      post user_confirmation_path, params: { user: { email: users(:unconfirmed).email } }
    end

    assert_redirected_to new_user_confirmation_path(email: users(:unconfirmed).email)
  end

  test "the whole flow reads in Portuguese and stays on the Portuguese pages" do
    get "/pt/register"

    assert_response :success
    assert_select "a.pn-auth__tab--register.is-active", text: I18n.t("account.tabs.register", locale: :pt)

    post "/pt/register", params: { user: registration_params }

    assert_redirected_to "/pt/confirmation/new?email=oak%40pallet.town"
    assert_equal I18n.t("devise.registrations.signed_up_but_unconfirmed", locale: :pt), flash[:notice]
  end

  private

  def registration_params
    { trainer_name: "OAK", email: "oak@pallet.town", password: PASSWORD,
      password_confirmation: PASSWORD, avatar: "green", terms: "1" }
  end

  def raw_confirmation_token
    ActionMailer::Base.deliveries.last.html_part.to_s[/confirmation_token=([^"&\s]+)/, 1] ||
      ActionMailer::Base.deliveries.last.body.to_s[/confirmation_token=([^"&\s]+)/, 1]
  end
end
