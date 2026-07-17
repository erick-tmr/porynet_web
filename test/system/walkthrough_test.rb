require "application_system_test_case"

class WalkthroughTest < ApplicationSystemTestCase
  test "the shared menu moves between the landing page and the walkthrough" do
    visit root_path

    within ".pn-nav__menu" do
      click_link "Walkthroughs"
    end

    assert_current_path walkthrough_path(game: "yellow")
    assert_selector ".pn-wt-hero__title", text: "Yellow"
    assert_selector "a.pn-nav__link.is-active", text: "Walkthroughs"

    within ".pn-nav__menu" do
      click_link "Home"
    end

    assert_current_path root_path
    assert_selector ".pn-hero__title", text: "steroids."
  end

  test "a route stop opens its location page and prev/next walks the slice" do
    visit walkthrough_path(game: "yellow")

    click_link "Viridian Forest"

    assert_current_path walkthrough_location_path(game: "yellow", location: "viridian-forest")
    assert_selector ".pn-wt-loc__title", text: "Forest"
    assert_selector ".pn-wt-catch__name", text: "Caterpie"
    assert_selector ".pn-wt-shot__img"

    click_link "Pewter City"

    assert_current_path walkthrough_location_path(game: "yellow", location: "pewter-city")
    assert_selector ".pn-wt-trainer__name", text: "Brock"
  end

  test "the language toggle keeps you on the walkthrough page in Portuguese" do
    visit walkthrough_location_path(game: "yellow", location: "viridian-forest")

    click_link "PT"

    assert_current_path walkthrough_location_path(game: "yellow", location: "viridian-forest", locale: :pt)
    assert_selector ".pn-eyebrow-label", text: "GUIA · ENTRADA → SAÍDA"
    assert_selector "a.pn-nav__lang", text: "EN"
  end
end
