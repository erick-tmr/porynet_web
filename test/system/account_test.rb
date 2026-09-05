require "application_system_test_case"

class AccountTest < ApplicationSystemTestCase
  test "a new trainer registers, picks an avatar and is told to open their inbox" do
    visit new_user_registration_path

    assert_selector ".pn-auth__tab--register.is-active"
    assert_selector "button.pn-auth__provider[disabled]", count: 4

    fill_in "user[trainer_name]", with: "OAK"
    fill_in "user[email]", with: "oak@pallet.town"
    fill_in "user[password]", with: "pikachu123"
    fill_in "user[password_confirmation]", with: "pikachu123"
    choose "user_avatar_green", allow_label_click: true
    check "user[terms]", allow_label_click: true
    click_on "CREATE SAVE FILE ▶"

    assert_current_path new_user_confirmation_path(email: "oak@pallet.town")
    assert_selector "[data-confirmation-email]", text: "oak@pallet.town"
    assert_equal "green", User.find_by(trainer_name: "OAK").avatar
  end

  test "the register form refuses to go through without the fan-project tick" do
    visit new_user_registration_path

    fill_in "user[trainer_name]", with: "OAK"
    fill_in "user[email]", with: "oak@pallet.town"
    fill_in "user[password]", with: "pikachu123"
    fill_in "user[password_confirmation]", with: "pikachu123"
    click_on "CREATE SAVE FILE ▶"

    assert_selector ".pn-form-errors__list li"
    assert_nil User.find_by(trainer_name: "OAK")
  end

  test "a confirmed trainer logs in by name and the header chip stops saying GUEST" do
    visit new_user_session_path

    assert_selector ".pn-nav__account-guest", text: "GUEST"

    fill_in "user[login]", with: "ASH"
    fill_in "user[password]", with: "pikachu123"
    click_on "PRESS START ▶"

    assert_current_path account_path
    assert_selector ".pn-nav__account-name", text: "ASH"
    assert_selector ".pn-auth__loaded-name", text: "Hello, ASH"
  end

  test "the account menu opens on the chip, shuts on Escape, and logs the trainer out" do
    login_as_user(users(:confirmed))
    visit account_path

    assert_selector ".pn-nav__account-menu", visible: :hidden

    find(".pn-nav__account-toggle").click

    assert_selector ".pn-nav__account-menu", visible: :visible
    assert_selector ".pn-nav__account-item--soon", count: 2

    find("body").send_keys :escape

    assert_selector ".pn-nav__account-menu", visible: :hidden

    find(".pn-nav__account-toggle").click
    click_on "Log out"

    assert_selector ".pn-nav__account-guest", text: "GUEST"
  end

  test "the tabs walk between the two forms" do
    visit new_user_session_path

    within(".pn-auth__tabs") { click_on "REGISTER" }

    assert_current_path new_user_registration_path
    assert_selector ".pn-auth__tab--register.is-active"

    within(".pn-auth__tabs") { click_on "LOG IN" }

    assert_current_path new_user_session_path
    assert_selector ".pn-auth__tab--login.is-active"
  end
end
