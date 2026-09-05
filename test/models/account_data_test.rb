require "test_helper"

class AccountDataTest < ActiveSupport::TestCase
  test "every list the account pages walk has copy behind it" do
    AccountData::OAUTH_PROVIDERS.each { |key| assert I18n.t("account.oauth.#{key}") }
    AccountData::UNLOCKS.each { |key| assert I18n.t("account.aside.items.#{key}.title") }
    AccountData::CONFIRMATION_STEPS.each { |key| assert I18n.t("account.confirmation.steps.#{key}") }
    AccountData::MENU_LINKS.each { |key| assert I18n.t("account.chip.#{key}") }
    AccountData::SECTIONS.each { |key| assert I18n.t("account.sections.#{key}") }
    AccountData::PASSWORD_RULES.each { |key| assert I18n.t("account.security.rules.#{key}") }
    AccountData::STRENGTH_LEVELS.each { |key| assert I18n.t("account.security.strength_levels.#{key}") }
    AccountData::BADGES.each { |key| assert I18n.t("account.card.badge_names.#{key}") }
    AccountData::AVATAR_GROUPS.each { |key| assert I18n.t("account.avatar.groups.#{key}") }
    AccountData::AVATARS.each { |avatar| assert I18n.t("account.avatars.#{avatar.id}.role") }
    AccountData::SAVES.each_key { |slug| assert I18n.t("account.card.spots.#{slug}") }
  end

  test "the numbers down the side of a list are two digits from one" do
    assert_equal "01", AccountData.unlock_number(0)
    assert_equal "04", AccountData.unlock_number(3)
  end

  test "every save the picker offers is a game the walkthrough index lists" do
    slugs = Walkthrough::Versions::CATALOGUE.pluck(:slug)

    assert_equal slugs.sort, AccountData::SAVES.keys.sort
  end

  test "an avatar is looked up by id, and an unknown one falls back to the first" do
    assert_equal "lance", AccountData.avatar("lance").id
    assert_predicate AccountData.avatar("lance"), :art?
    assert_equal AccountData::AVATARS.first, AccountData.avatar("porygon")
    assert_not_predicate AccountData.avatar("red"), :art?
  end

  test "a group narrows the roster and all keeps the whole of it" do
    assert_equal AccountData::AVATARS, AccountData.avatars_in("all")
    assert_equal %w[red blue green], AccountData.avatars_in("heroes").map(&:id)
  end

  test "only a group the picker draws is honoured, anything else means all" do
    assert_equal "elite", AccountData.avatar_group("elite")
    assert_equal "all", AccountData.avatar_group("champions")
    assert_equal "all", AccountData.avatar_group(nil)
  end

  test "an unknown game reads the first save rather than none at all" do
    assert_equal "blue", AccountData.save_for("blue").slug
    assert_equal AccountData::SAVES.values.first, AccountData.save_for("crystal")
    assert_equal AccountData::SAVES.values.first, AccountData.save_for(nil)
  end

  test "a save counts its own badges and says when it has none" do
    assert_equal 8, AccountData.save_for("blue").badge_count
    assert_predicate AccountData.save_for("blue"), :badges?
    assert_not_predicate AccountData.save_for("green"), :badges?
  end

  test "the trainer id is the record id padded to five digits" do
    assert_equal "00151", AccountData.trainer_id(User.new(id: 151))
  end

  test "the signup picker offers a subset of the roster" do
    assert_equal AccountData::SIGNUP_AVATARS, AccountData::SIGNUP_AVATARS & AccountData.avatar_ids
  end
end
