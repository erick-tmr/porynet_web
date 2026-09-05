require "test_helper"

class AccountDataTest < ActiveSupport::TestCase
  test "every list the account pages walk has copy behind it" do
    AccountData::OAUTH_PROVIDERS.each { |key| assert I18n.t("account.oauth.#{key}") }
    AccountData::UNLOCKS.each { |key| assert I18n.t("account.aside.items.#{key}.title") }
    AccountData::CONFIRMATION_STEPS.each { |key| assert I18n.t("account.confirmation.steps.#{key}") }
    AccountData::MENU_LINKS.each { |key| assert I18n.t("account.chip.#{key}") }
  end

  test "the numbers down the side of a list are two digits from one" do
    assert_equal "01", AccountData.unlock_number(0)
    assert_equal "04", AccountData.unlock_number(3)
  end
end
