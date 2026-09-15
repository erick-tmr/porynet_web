require "test_helper"

class OmniauthTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  NEW_UID = "204871639205748120394".freeze

  setup do
    OmniAuth.config.test_mode = true
    OmniAuth.config.logger = Rails.logger
  end

  teardown do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  test "a trainer who already linked Google is signed straight in" do
    google(uid: identities(:gary_google).uid, email: "gary@pallet.town")
    sign_in_with_google

    assert_redirected_to account_path
    follow_redirect!
    assert_select ".pn-account__name", text: "GARY"
  end

  test "a first Google sign in asks for a trainer name and opens the save file" do
    google(uid: NEW_UID, email: "brock@rock.gym")
    sign_in_with_google

    assert_redirected_to new_user_omniauth_registration_path
    follow_redirect!
    assert_select ".pn-auth__identity-name", text: "brock@rock.gym"

    assert_difference [ "User.count", "Identity.count" ], 1 do
      post user_omniauth_registration_path,
           params: { user: { trainer_name: "BROCKJR", avatar: "green", terms: "1" } }
    end

    trainer = User.find_by(trainer_name: "BROCKJR")
    assert_redirected_to account_path
    assert_equal "brock@rock.gym", trainer.email
    assert trainer.confirmed?, "Google verified the address, so nothing is left to confirm"
    assert_not trainer.password_set?, "no password was asked for, so none should be set"
    assert_equal NEW_UID, trainer.identities.sole.uid
    assert_empty ActionMailer::Base.deliveries
  end

  test "a rejected trainer name keeps the pending sign up alive" do
    google(uid: NEW_UID, email: "brock@rock.gym")
    sign_in_with_google
    follow_redirect!

    assert_no_difference "User.count" do
      post user_omniauth_registration_path,
           params: { user: { trainer_name: "ASH", avatar: "red", terms: "1" } }
    end

    assert_response :unprocessable_entity
    assert_select ".pn-form-errors"
    assert_select ".pn-auth__identity-name", text: "brock@rock.gym"
  end

  test "an address that is already a trainer is sent to log in rather than linked" do
    google(uid: NEW_UID, email: users(:confirmed).email)
    sign_in_with_google

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("account.oauth.email_taken", email: users(:confirmed).email,
                                                     provider: "Google"), flash[:alert]
    assert_nil Identity.find_by(uid: NEW_UID)
  end

  test "an address Google has not verified opens nothing" do
    google(uid: NEW_UID, email: "spoof@gmail.com", verified: false)
    sign_in_with_google

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("account.oauth.unverified", provider: "Google"), flash[:alert]
    assert_nil Identity.find_by(uid: NEW_UID)
  end

  test "a signed in trainer connects Google from the security page" do
    sign_in users(:confirmed)
    google(uid: NEW_UID, email: "ash@gmail.com")

    assert_difference "Identity.count", 1 do
      sign_in_with_google
    end

    assert_redirected_to account_security_path
    assert_equal "ash@gmail.com", users(:confirmed).identities.sole.email
  end

  test "a Google account already on another trainer is refused, not moved" do
    sign_in users(:confirmed)
    google(uid: identities(:gary_google).uid, email: "gary@pallet.town")

    assert_no_difference "Identity.count" do
      sign_in_with_google
    end

    assert_redirected_to account_security_path
    assert_equal I18n.t("account.oauth.taken", provider: "Google"), flash[:alert]
    assert_equal users(:rival), identities(:gary_google).reload.user
  end

  test "a trainer who already connected one Google account cannot add a second" do
    sign_in users(:linked)
    google(uid: NEW_UID, email: "other@gmail.com")

    assert_no_difference "Identity.count" do
      sign_in_with_google
    end

    assert_redirected_to account_security_path
    assert_equal I18n.t("account.oauth.already_connected", provider: "Google"), flash[:alert]
  end

  test "connecting the account already connected says so without a second row" do
    sign_in users(:linked)
    google(uid: identities(:daisy_google).uid, email: "daisy@pallet.town")

    assert_no_difference "Identity.count" do
      sign_in_with_google
    end

    assert_redirected_to account_security_path
    assert_equal I18n.t("account.oauth.linked", provider: "Google"), flash[:notice]
  end

  test "a sign in that fails at Google lands back on the login page" do
    OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials
    post user_google_oauth2_omniauth_authorize_path
    follow_redirect!

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("devise.omniauth_callbacks.failure_generic"), flash[:alert]
  end

  test "a Portuguese sign in comes back to Portuguese" do
    google(uid: NEW_UID, email: "brock@rock.gym")
    sign_in_with_google(locale: "pt")

    assert_redirected_to new_user_omniauth_registration_path(locale: "pt")
    follow_redirect!
    assert_select "html[lang=?]", "pt"
  end

  test "an existing trainer signing in under pt lands on the pt account page" do
    google(uid: identities(:gary_google).uid, email: "gary@pallet.town")
    sign_in_with_google(locale: "pt")

    assert_redirected_to account_path(locale: "pt")
  end

  test "a locale nobody serves falls back to English" do
    google(uid: identities(:gary_google).uid, email: "gary@pallet.town")
    sign_in_with_google(locale: "de")

    assert_redirected_to account_path
  end

  test "a pending sign up that sat too long is thrown away" do
    google(uid: NEW_UID, email: "brock@rock.gym")
    sign_in_with_google

    travel (OauthStash::WINDOW + 1.minute) do
      get new_user_omniauth_registration_path

      assert_redirected_to new_user_session_path
      assert_equal I18n.t("account.oauth.expired"), flash[:alert]
    end
  end

  test "the completion form is closed to anyone without a pending sign in" do
    get new_user_omniauth_registration_path

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("account.oauth.expired"), flash[:alert]
  end

  test "a Google account claimed while the form sat open makes no second trainer" do
    google(uid: NEW_UID, email: "brock@rock.gym")
    sign_in_with_google
    Identity.create!(user: users(:confirmed), provider: "google", uid: NEW_UID)

    assert_no_difference "User.count" do
      post user_omniauth_registration_path,
           params: { user: { trainer_name: "BROCKJR", avatar: "green", terms: "1" } }
    end

    assert_response :unprocessable_entity
    assert_select ".pn-form-errors"
  end

  test "a duplicate submit that races the unique index is turned away, not 500ed" do
    google(uid: NEW_UID, email: "brock@rock.gym")
    sign_in_with_google

    doomed = User.new
    def doomed.save(*) = raise(ActiveRecord::RecordNotUnique, "index_identities_on_provider_and_uid")
    User.define_singleton_method(:new) { |*| doomed }

    assert_no_difference "User.count" do
      post user_omniauth_registration_path,
           params: { user: { trainer_name: "BROCKJR", avatar: "green", terms: "1" } }
    end
  ensure
    User.singleton_class.remove_method(:new)

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("account.oauth.taken", provider: "Google"), flash[:alert]
  end

  private

  def google(uid:, email:, verified: true)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: (email if verified), email_verified: verified, name: "Trainer" },
      extra: { id_info: { "email_verified" => verified } }
    )
  end

  def sign_in_with_google(locale: nil)
    post user_google_oauth2_omniauth_authorize_path(locale: locale)
    follow_redirect!
  end
end
