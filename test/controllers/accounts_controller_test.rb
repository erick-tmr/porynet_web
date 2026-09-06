require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  SECTIONS = { card: "/account", avatar: "/account/avatar",
               security: "/account/security", save_file: "/account/save" }.freeze

  test "no section of the account is readable as a guest" do
    SECTIONS.each_value do |path|
      get path

      assert_redirected_to new_user_session_path
    end
  end

  test "the rail marks the section being read and links to the other three" do
    sign_in users(:confirmed)

    SECTIONS.each do |section, path|
      get path

      assert_response :success
      assert_select ".pn-account__rail-item.is-active .pn-account__rail-label", count: 1,
                    text: I18n.t("account.sections.#{section}")
      assert_select ".pn-account__rail-item", count: AccountData::SECTIONS.size
    end
  end

  test "the trainer card carries the name, the address and the avatar the trainer picked" do
    sign_in users(:confirmed)
    get account_path

    assert_select ".pn-account__name", text: "ASH"
    assert_select ".pn-account__meta", /ash@pallet\.town/
    assert_select ".pn-account__avatar-frame img[src*=?]", "account/avatars/red.png"
    assert_select "a[href=?]", account_avatar_path
    assert_select "a[href=?]", account_security_path
  end

  test "the card draws the avatar art of a trainer who picked a painted portrait" do
    users(:rival).update!(avatar: "lance-art")
    sign_in users(:rival)
    get account_path

    assert_select ".pn-account__avatar-frame img.pn-art[src*=?]", "walkthrough/art/lance-art.png"
    assert_select ".pn-nav__account-name", text: "GARY"
  end

  test "picking a game swaps the save file the card reports" do
    sign_in users(:confirmed)
    get account_path(game: "blue")

    assert_select ".pn-account__game.is-open .pn-account__game-name", text: "Pokémon Blue"
    assert_select ".pn-account__stat-value", text: "151 / 151"
    assert_select ".pn-account__badge", count: AccountData::BADGES.size
  end

  test "a save with no badges yet says so instead of drawing an empty row" do
    sign_in users(:confirmed)
    get account_path(game: "green")

    assert_select ".pn-account__badges", count: 0
    assert_select ".pn-account__badges-empty", text: I18n.t("account.card.no_badges")
  end

  test "an unknown game falls back to the first save rather than blowing up" do
    sign_in users(:confirmed)
    get account_path(game: "crystal")

    assert_response :success
    assert_select ".pn-account__game.is-open .pn-account__game-name", text: "Pokémon Yellow"
  end

  test "the avatar picker pages the roster and marks the one in use" do
    sign_in users(:confirmed)
    get account_avatar_path

    assert_select ".pn-auth__avatar", count: AccountData::PAGE_SIZE
    assert_select ".pn-account__pager a", count: 1

    get account_avatar_path(q: AccountData.avatar(users(:confirmed).avatar).name)

    assert_select ".pn-account__avatar-inuse", count: 1
    assert_select "input[name=?][checked=checked]", "account_avatar[avatar]"
  end

  test "picking a trainer saves it and lands back on the page it was picked from" do
    sign_in users(:confirmed)
    patch account_avatar_path,
          params: { account_avatar: { avatar: "cynthia" }, gen: "gen4", q: "cyn", page: "1" }

    assert_redirected_to account_avatar_path(gen: "gen4", q: "cyn", page: "1")
    assert_equal "cynthia", users(:confirmed).reload.avatar
    assert_equal I18n.t("account.avatar.saved", name: "Cynthia"), flash[:notice]
  end

  test "a trainer who is not on the roster is refused and changes nothing" do
    sign_in users(:confirmed)
    patch account_avatar_path, params: { account_avatar: { avatar: "porygon" } }

    assert_redirected_to account_avatar_path
    assert_equal "red", users(:confirmed).reload.avatar
    assert_equal I18n.t("account.avatar.rejected"), flash[:alert]
  end

  test "a guest cannot set an avatar" do
    patch account_avatar_path, params: { account_avatar: { avatar: "cynthia" } }

    assert_redirected_to new_user_session_path
  end

  test "the saved trainer is the one the header and the card then draw" do
    sign_in users(:confirmed)
    patch account_avatar_path, params: { account_avatar: { avatar: "lance-art" } }
    get account_path

    assert_select ".pn-account__avatar-frame img[src*=?]", "walkthrough/art/lance-art.png"
    assert_select ".pn-nav__account-mark img[src*=?]", "walkthrough/art/lance-art.png"
  end

  test "the picker names Showdown, whose community drew every sprite in it" do
    sign_in users(:confirmed)
    get account_avatar_path

    assert_select ".pn-account__credit a[href=?]", ApplicationHelper::SOURCE_URLS[:showdown]
  end

  test "a generation chip narrows the roster, and an unknown generation shows everybody" do
    sign_in users(:confirmed)
    get account_avatar_path(gen: "gen1")

    assert_select ".pn-account__filter.is-active", text: I18n.t("account.avatar.generations.gen1")
    assert_select ".pn-auth__avatar", count: AccountData::PAGE_SIZE

    get account_avatar_path(gen: "gen12")

    assert_select ".pn-account__filter.is-active", text: I18n.t("account.avatar.generations.all")
  end

  test "searching keeps the generation, and an empty result says so instead of drawing a grid" do
    sign_in users(:confirmed)
    get account_avatar_path(gen: "gen1", q: "brock")

    assert_select ".pn-auth__avatar", count: 2
    assert_select ".pn-account__filter.is-active", text: I18n.t("account.avatar.generations.gen1")

    get account_avatar_path(q: "nobody-here")

    assert_select ".pn-auth__avatar", count: 0
    assert_select ".pn-account__badges-empty"
  end

  test "a page past the end lands on the last page rather than an empty grid" do
    sign_in users(:confirmed)
    get account_avatar_path(page: 99_999)

    assert_response :success
    assert_select ".pn-auth__avatar", minimum: 1
  end

  test "the security page draws the email, password and linked-login panels" do
    sign_in users(:confirmed)
    get account_security_path

    assert_select ".pn-account__current-value", text: "ash@pallet.town"
    assert_select "form[action=?]", account_security_email_path
    assert_select "form[action=?]", account_security_password_path
    assert_select "input[name=?]", "account_email[email_confirmation]"
    assert_select "input[type=submit][disabled]", count: 0
    assert_select "[data-controller=?]", "password-strength"
    assert_select ".pn-account__rule", count: AccountData::PASSWORD_RULES.size
    assert_select ".pn-account__strength-label", count: AccountData::STRENGTH_LEVELS.size
    assert_select ".pn-account__social", count: AccountData::OAUTH_PROVIDERS.size
    assert_select "a[href=?]", new_user_password_path
  end

  test "the save file page offers the logout and arms the delete behind a disclosure" do
    sign_in users(:confirmed)
    get account_save_file_path

    assert_select "form[action=?][method=post]", destroy_user_session_path
    assert_select ".pn-account__danger[data-controller=?]", "disclosure"
    assert_select ".pn-account__danger-actions[hidden]"
    assert_select ".pn-account__danger-go[disabled]"
  end

  test "the Portuguese twin of every section renders" do
    sign_in users(:confirmed)

    SECTIONS.each_value do |path|
      get "/pt#{path}"

      assert_response :success
      assert_select "html[lang=?]", "pt"
    end
  end
end
