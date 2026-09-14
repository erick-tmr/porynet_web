require "test_helper"

class OmniauthLinkerTest < ActiveSupport::TestCase
  NEW_UID = "309285710394857102938".freeze

  test "an address Google did not verify gets no further" do
    result = OmniauthLinker.new(auth(email: nil, verified: false)).call

    assert_equal :unverified, result.status
    assert_nil result.user
  end

  test "a signed token that says the address is unverified overrides a present address" do
    result = OmniauthLinker.new(auth(email: "spoof@gmail.com", verified: false)).call

    assert_equal :unverified, result.status
  end

  test "a reply with no id token falls back to the address the strategy vetted" do
    auth = OmniAuth::AuthHash.new(provider: "google_oauth2", uid: NEW_UID,
                                  info: { email: "brock@rock.gym" })
    result = OmniauthLinker.new(auth).call

    assert_equal :signup, result.status
    assert_equal "brock@rock.gym", result.email
  end

  test "a known uid resolves to its trainer" do
    result = OmniauthLinker.new(auth(uid: identities(:gary_google).uid)).call

    assert_equal :signed_in, result.status
    assert_equal users(:rival), result.user
  end

  test "an unknown uid on a known address stops rather than guessing" do
    result = OmniauthLinker.new(auth(email: users(:confirmed).email)).call

    assert_equal :email_taken, result.status
    assert_equal users(:confirmed).email, result.email
  end

  test "an unknown uid on an unknown address is a new trainer" do
    result = OmniauthLinker.new(auth).call

    assert_equal :signup, result.status
    assert_equal "google", result.provider
  end

  test "the credentials handed to the signup form are the verified ones" do
    linker = OmniauthLinker.new(auth(email: "brock@rock.gym"))

    assert_equal({ "provider" => "google", "uid" => NEW_UID, "email" => "brock@rock.gym" },
                 linker.credentials)
  end

  test "a signed in trainer links a fresh account" do
    assert_difference "Identity.count", 1 do
      result = OmniauthLinker.new(auth, users(:confirmed)).call

      assert_equal :linked, result.status
      assert_equal users(:confirmed), result.user
    end
  end

  test "linking the account already linked here changes nothing" do
    identity = identities(:daisy_google)

    assert_no_difference "Identity.count" do
      result = OmniauthLinker.new(auth(uid: identity.uid), users(:linked)).call

      assert_equal :linked, result.status
    end
  end

  test "linking an account that signs in someone else is refused" do
    identity = identities(:gary_google)

    assert_no_difference "Identity.count" do
      result = OmniauthLinker.new(auth(uid: identity.uid), users(:confirmed)).call

      assert_equal :taken, result.status
    end
  end

  test "a second Google account on one trainer is refused" do
    assert_no_difference "Identity.count" do
      result = OmniauthLinker.new(auth, users(:linked)).call

      assert_equal :already_connected, result.status
    end
  end

  private

  def auth(uid: NEW_UID, email: "brock@rock.gym", verified: true)
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: email, email_verified: verified },
      extra: { id_info: { "email_verified" => verified } }
    )
  end
end
