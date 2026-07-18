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

  test "an index leg opens a merged multi-location page and walks to the next leg" do
    visit walkthrough_path(game: "yellow")

    find("a.pn-wt-route__card[href$='/leg-01']").click

    assert_current_path walkthrough_leg_path(game: "yellow", leg: "leg-01")
    assert_selector ".pn-wt-band__title", text: "Pallet Town"
    assert_selector ".pn-wt-band__title", text: "Route 1"
    assert_selector ".pn-wt-chip", minimum: 2

    find(".pn-wt-nav__link--next").click
    assert_current_path walkthrough_leg_path(game: "yellow", leg: "leg-02")
  end

  test "a special stop opens its dedicated page and the language toggle stays put" do
    visit walkthrough_path(game: "yellow")

    find("a.pn-wt-route__card[href$='/viridian-forest']").click

    assert_current_path walkthrough_leg_path(game: "yellow", leg: "viridian-forest")
    assert_selector ".pn-wt-loc__title", text: "Forest"
    assert_no_selector ".pn-wt-chip"

    click_link "PT"

    assert_current_path walkthrough_leg_path(game: "yellow", leg: "viridian-forest", locale: :pt)
    assert_selector "a.pn-nav__lang", text: "EN"
  end
end
