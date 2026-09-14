require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  test "a provider nobody offers is rejected" do
    identity = Identity.new(user: users(:confirmed), provider: "myspace", uid: "1")

    assert_not identity.valid?
    assert_includes identity.errors.attribute_names, :provider
  end

  test "one Google account cannot sign in two trainers" do
    taken = identities(:gary_google)
    identity = Identity.new(user: users(:confirmed), provider: taken.provider, uid: taken.uid)

    assert_not identity.valid?
    assert_includes identity.errors.attribute_names, :uid
  end

  test "the same uid on a different provider is a different account" do
    taken = identities(:gary_google)
    identity = Identity.new(user: users(:confirmed), provider: "github", uid: taken.uid)

    assert identity.valid?
  end

  test "deleting a trainer takes their linked logins with them" do
    assert_difference "Identity.count", -1 do
      users(:rival).destroy
    end
  end
end
