require "test_helper"

class AccountDataTest < ActiveSupport::TestCase
  test "every list the account pages walk has copy behind it" do
    AccountData::OAUTH_PROVIDERS.each { |key| assert I18n.t("account.oauth.#{key}") }
    AccountData::UNLOCKS.each { |key| assert I18n.t("account.aside.items.#{key}.title") }
    AccountData::CONFIRMATION_STEPS.each { |key| assert I18n.t("account.confirmation.steps.#{key}") }
    AccountData::SECTIONS.each { |key| assert I18n.t("account.sections.#{key}") }
    AccountData::PASSWORD_RULES.each { |key| assert I18n.t("account.security.rules.#{key}") }
    AccountData::STRENGTH_LEVELS.each { |key| assert I18n.t("account.security.strength_levels.#{key}") }
    AccountData::BADGES.each { |key| assert I18n.t("account.card.badge_names.#{key}") }
    AccountData::ERAS.each { |key| assert I18n.t("account.avatar.eras.#{key}") }
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
    assert_equal "Brock", AccountData.avatar("brock-gen1").name
    assert_predicate AccountData.avatar("lance-art"), :art?
    assert_equal AccountData::AVATARS.first, AccountData.avatar("porygon")
    assert_not_predicate AccountData.avatar("brock-gen1"), :art?
  end

  test "every avatar in the manifest is unique, named and filed under a real era" do
    ids = AccountData.avatar_ids

    assert_equal ids.size, ids.uniq.size
    assert_empty AccountData::AVATARS.reject { |avatar| avatar.name.present? }
    assert_empty AccountData::AVATARS.map(&:era).uniq - AccountData::ERAS
  end

  test "an era narrows the roster and all keeps the whole of it" do
    assert_equal AccountData::AVATARS, AccountData.search(era: "all", query: "")
    assert_empty AccountData.search(era: "gen1", query: "").reject { |a| a.era == "gen1" }
  end

  test "only an era the picker draws is honoured, anything else means all" do
    assert_equal "gen3", AccountData.era("gen3")
    assert_equal "all", AccountData.era("gen12")
    assert_equal "all", AccountData.era(nil)
  end

  test "search matches a name inside the chosen era and ignores case" do
    assert_equal %w[brock-gen1 brock-gen1rb], AccountData.search(era: "gen1", query: "BRO").map(&:id)
    assert_empty AccountData.search(era: "gen1", query: "nobody-here")
  end

  test "a page clamps to the roster it is given" do
    rows = AccountData::AVATARS
    first = AccountData.page(rows, nil)

    assert_predicate first, :first?
    assert_equal 1, first.number
    assert_equal AccountData::PAGE_SIZE, first.rows.size

    last = AccountData.page(rows, 99_999)

    assert_predicate last, :last?
    assert_predicate last, :many?

    only = AccountData.page(rows.first(3), 2)

    assert_equal 1, only.total
    assert_equal 3, only.rows.size
    assert_not_predicate only, :many?
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
