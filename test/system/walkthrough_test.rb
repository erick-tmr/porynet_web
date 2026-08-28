require "application_system_test_case"

class WalkthroughTest < ApplicationSystemTestCase
  def resize_to(width, height)
    Capybara.current_session.current_window.resize_to(width, height)
  end

  def rect(selector)
    page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()")
  end

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
    assert_selector ".pn-legsw__chip", minimum: 2

    find(".pn-wt-nav__link--next").click
    assert_current_path walkthrough_leg_path(game: "yellow", leg: "leg-02")
  end

  test "switching Oak on from the index carries onto a leg page and survives a reload" do
    visit walkthrough_path(game: "yellow")

    assert_selector ".pn-wt-modechip--oak[aria-pressed='false']"
    find(".pn-nav__modes .pn-modesw--oak").click
    assert_selector ".pn-wt-modechip--oak[aria-pressed='true']"
    assert_selector ".pn-wt-modeid__cta--oak[aria-pressed='true']"

    visit walkthrough_leg_path(game: "yellow", leg: "leg-02")

    assert_selector ".pn-wt-loc__title"
    assert_selector ".pn-wt-oak"

    visit walkthrough_leg_path(game: "yellow", leg: "leg-02")

    assert_selector ".pn-wt-oak"
    find(".pn-nav__modes .pn-modesw--oak").click
    assert_no_selector ".pn-wt-oak"
  end

  test "the section's own button switches a mode on, like every other switch" do
    visit walkthrough_path(game: "yellow")

    assert_no_selector ".pn-wt-modeid__cta--living[aria-pressed='true']"
    find(".pn-wt-modeid__cta--living").click

    assert_selector ".pn-wt-modechip--living[aria-pressed='true']"
    assert_selector ".pn-nav__modes .pn-modesw--living[aria-pressed='true']"
    assert_selector ".pn-wt-modeid__cta--oak[aria-pressed='false']"
  end

  test "on a narrow window the burger panel is where the modes live" do
    resize_to(430, 900)

    visit walkthrough_path(game: "yellow")

    assert_no_selector ".pn-nav__modes", visible: true
    find(".pn-nav__burger").click

    assert_selector ".pn-nav__burger[aria-expanded='true']"
    within "#pn-nav-panel" do
      click_button I18n.t("walkthrough.ui.mode_oak_title")
    end

    assert_selector ".pn-wt-modechip--oak[aria-pressed='true']"

    visit walkthrough_leg_path(game: "yellow", leg: "leg-02")
    assert_selector ".pn-wt-oak"
  ensure
    resize_to(1400, 1000)
  end

  test "on a narrow window the jump bar is a stepper that opens the whole stop list" do
    resize_to(430, 900)

    visit walkthrough_leg_path(game: "yellow", leg: "leg-08")

    assert_no_selector ".pn-legsw__rail", visible: true
    assert_selector ".pn-legsw__current-name", text: "Route 10"
    assert_selector ".pn-legsw__count", text: "1/5"

    find(".pn-legsw__current").click
    assert_selector ".pn-legsw__sheet", visible: true
    find(".pn-legsw__row-name", text: "Route 8").click

    assert_no_selector ".pn-legsw__sheet", visible: true
    assert_selector ".pn-legsw__current-name", text: "Route 8"
    assert_selector ".pn-legsw__count", text: "3/5"
    assert_selector ".pn-legsw__seg.is-here", count: 1

    # the bar parks flush under the nav at whatever height the nav measures
    assert_in_delta rect(".pn-nav")["bottom"], rect(".pn-legsw")["top"], 1
  ensure
    resize_to(1400, 1000)
  end

  # The rate-by-floor rows on one card exist to be read against each other, so the bar is only
  # honest if every row draws it in the same place at the same width. Sized row by row they were
  # not: a "Center" chip is wider than a "West" one, and it stole the difference from its own bar,
  # so two floors at the same rate drew different lengths. The Safari Zone is the page that shows
  # it, being the one whose floors have names rather than numbers.
  test "every rate bar on a card is the same size, whatever its floor is called" do
    visit walkthrough_leg_path(game: "yellow", leg: "safari-zone")

    assert_selector ".pn-wt-floors__list--floors"
    boxes = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.pn-wt-floors__list')].map(list =>
        [...list.querySelectorAll('.pn-wt-floors__track')].map(track => {
          const box = track.getBoundingClientRect();
          return [Math.round(box.x), Math.round(box.width)];
        }))
    JS

    refute_empty boxes
    boxes.each { |card| assert_equal 1, card.uniq.size, "a card's tracks must share one column" }
  end

  # The catching explainer is three folded panels and the answer they point at. Folded is the point:
  # a reader who only wants the verdict should see it without scrolling past the arithmetic, and a
  # reader who wants the arithmetic should get it without leaving the page.
  test "the Safari catching panels stay folded until asked, and the answer is always out" do
    visit walkthrough_leg_path(game: "yellow", leg: "safari-zone")

    assert_selector "#catching .pn-sc__verdict-text", text: /Throw a ball every turn/
    assert_selector "#catching .pn-sc__panel", count: 3
    assert_no_selector "#catching .pn-sc__body", visible: true

    find(".pn-sc__head[aria-controls='pn-sc-algorithm']").click

    assert_selector "#pn-sc-algorithm", visible: true, text: "BallFactor = 12"
    assert_selector ".pn-sc__head[aria-controls='pn-sc-algorithm'][aria-expanded='true']"
  end

  test "a special stop opens its dedicated page and the language toggle stays put" do
    visit walkthrough_path(game: "yellow")

    find("a.pn-wt-route__card[href$='/viridian-forest']").click

    assert_current_path walkthrough_leg_path(game: "yellow", leg: "viridian-forest")
    assert_selector ".pn-wt-loc__title", text: "Forest"
    assert_no_selector ".pn-legsw__chip"

    click_link "PT"

    assert_current_path walkthrough_leg_path(game: "yellow", leg: "viridian-forest", locale: :pt)
    assert_selector "a.pn-nav__lang", text: "EN"
  end
end
