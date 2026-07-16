require "application_system_test_case"

class LandingTest < ApplicationSystemTestCase
  test "renders the landing page with all sections" do
    visit root_path

    assert_selector ".pn-wordmark", text: "PORYNET"
    assert_text "Your PC box,"
    assert_text "A collection tracker that finally does it all."
    assert_text "Catch 'em all"
    assert_text "Every box, every specimen."
    assert_text "Your Pokémon, saved on your computer, whenever you want."
    assert_text "All nine gens incoming."
    assert_text "not affiliated with Nintendo, Game Freak or The Pokémon Company"
    assert_selector "img[src*='porygon']"
    assert_selector ".pn-slot__sprite[src*='pokemon/']"
  end

  test "Oak / Living Dex toggle flips the active mode" do
    visit root_path

    assert_selector ".pn-toggle__btn.is-active", text: "OAK MODE"
    assert_selector ".pn-oak-subcard--oak.is-active"
    assert_no_selector ".pn-oak-subcard--dex.is-active"

    click_button "LIVING DEX"

    assert_selector ".pn-toggle__btn.is-active", text: "LIVING DEX"
    assert_no_selector ".pn-toggle__btn.is-active", text: "OAK MODE"
    assert_selector ".pn-oak-subcard--dex.is-active"
    assert_no_selector ".pn-oak-subcard--oak.is-active"
  end

  test "city selector updates the stat panel" do
    visit root_path

    assert_selector ".pn-city-btn.is-active", text: "PEWTER CITY"
    assert_selector ".pn-oak-stat__city", text: "PEWTER CITY"
    assert_selector ".pn-oak-stat__total", text: "12"

    click_button "CERULEAN CITY"

    assert_selector ".pn-city-btn.is-active", text: "CERULEAN CITY"
    assert_selector ".pn-oak-stat__city", text: "CERULEAN CITY"
    assert_selector ".pn-oak-stat__total", text: "22"
    within ".pn-oak-new__mons" do
      assert_text "Psyduck"
    end
  end

  test "language toggle switches the whole page to Portuguese" do
    visit root_path

    assert_selector ".pn-hero__title", text: "steroids."
    click_link "PT"

    assert_current_path "/pt"
    assert_selector ".pn-hero__title", text: "turbinada."
    assert_selector "a.pn-nav__lang", text: "EN"
    assert_text "Seus Pokémon, salvos no seu computador"
  end
end
