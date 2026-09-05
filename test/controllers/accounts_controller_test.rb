require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "the account page is not readable as a guest" do
    get account_path

    assert_redirected_to new_user_session_path
  end

  test "a logged-in trainer sees the save file and the way back out" do
    sign_in users(:confirmed)
    get account_path

    assert_response :success
    assert_select ".pn-auth__loaded-name", text: I18n.t("account.show.greeting", name: "ASH")
    assert_select ".pn-auth__loaded-mark img[src*=?]", "account/avatars/red.png"
    assert_select "a[href=?]", walkthroughs_path
    assert_select "form[action=?][method=post]", destroy_user_session_path
  end

  test "the avatar on the page is the one the trainer picked" do
    sign_in users(:rival)
    get account_path

    assert_select ".pn-auth__loaded-mark img[src*=?]", "account/avatars/blue.png"
    assert_select ".pn-nav__account-name", text: "GARY"
  end
end
