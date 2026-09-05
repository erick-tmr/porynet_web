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
    assert_selector ".pn-account__name", text: "ASH"
  end

  test "the one menu opens on the chip, shuts on Escape, and logs the trainer out" do
    login_as_user(users(:confirmed))
    visit account_path

    assert_selector ".pn-nav__menu", visible: :hidden

    find(".pn-nav__account-toggle").click

    assert_selector ".pn-nav__menu", visible: :visible
    within ".pn-nav__menu" do
      assert_selector ".pn-nav__menu-link", text: "Walkthroughs"
      assert_selector ".pn-nav__menu-link", text: "Trainer card"
    end

    find("body").send_keys :escape

    assert_selector ".pn-nav__menu", visible: :hidden

    find(".pn-nav__account-toggle").click
    click_on "Log out"

    assert_selector ".pn-nav__account-guest", text: "GUEST"
  end

  test "a guest reaches the login through the same menu" do
    visit root_path

    find(".pn-nav__account-toggle").click

    within ".pn-nav__menu" do
      click_link I18n.t("account.chip.login")
    end

    assert_current_path new_user_session_path
  end

  test "the rail walks the four sections of the account" do
    login_as_user(users(:confirmed))
    visit account_path

    within(".pn-account__rail") { click_on "Avatar" }

    assert_current_path account_avatar_path
    assert_selector ".pn-auth__avatar", count: AccountData::PAGE_SIZE

    within(".pn-account__rail") { click_on "Login and security" }

    assert_current_path account_security_path
    assert_selector ".pn-account__pill", text: "VERIFIED"

    within(".pn-account__rail") { click_on "Save file" }

    assert_current_path account_save_file_path
    assert_selector ".pn-account__rail-item.is-active", text: "Save file"
  end

  test "a trainer picks an avatar and it sticks" do
    login_as_user(users(:confirmed))
    visit account_avatar_path(q: "cynthia")

    assert_selector ".pn-auth__avatar", minimum: 1

    find("label.pn-auth__avatar", match: :first).click
    click_on "SAVE AVATAR ▶"

    assert_selector ".pn-flash__msg--notice"
    assert_selector ".pn-account__avatar-inuse"
    assert_equal "cynthia", users(:confirmed).reload.avatar

    visit account_path

    assert_selector ".pn-account__avatar-name", text: "Cynthia"
  end

  test "the strength meter fills as a password is typed" do
    login_as_user(users(:confirmed))
    visit account_security_path

    assert_selector ".pn-account__rule.is-ok", count: 0

    fill_in "account_password[password]", with: "pikachu12345!"

    assert_selector ".pn-account__rule.is-ok", count: 3
    assert_selector ".pn-account__strength-label--4", visible: :visible
  end

  test "deleting the account has to be armed first, and can be waved off" do
    login_as_user(users(:confirmed))
    visit account_save_file_path

    assert_selector ".pn-account__danger-actions", visible: :hidden

    click_on "DELETE MY ACCOUNT"

    assert_selector ".pn-account__danger-actions", visible: :visible

    click_on "KEEP MY SAVE"

    assert_selector ".pn-account__danger-actions", visible: :hidden
    assert_selector ".pn-account__danger-arm", visible: :visible
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
