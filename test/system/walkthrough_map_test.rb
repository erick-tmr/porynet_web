require "application_system_test_case"

class WalkthroughMapTest < ApplicationSystemTestCase
  FOREST = "/walkthroughs/yellow/viridian-forest".freeze
  TRAINER = ".pn-mm[data-marker-id='trainer-30-33']".freeze

  def visit_forest
    visit FOREST
    assert_selector ".pn-mm-layer.is-ready"
  end

  test "the map draws a marker for everything the game data holds" do
    visit_forest

    assert_selector ".pn-mm", count: 12
    assert_selector ".pn-mm-legend__row", count: 12
    assert_selector ".pn-mm-legend__chip", text: "A"
  end

  test "markers are placed from their own coordinates, not stacked in a corner" do
    visit_forest

    # the custom properties the controller writes, not the laid-out pixels: percentages resolve
    # against the map image, so measuring those would only be testing whether it had loaded yet
    spots = page.all(".pn-mm").map do |marker|
      marker.evaluate_script("[this.style.getPropertyValue('--mx'), this.style.getPropertyValue('--my')]")
    end

    assert_equal 12, spots.uniq.size, "no two markers should share a spot"
    assert(spots.flatten.all? { |offset| offset.end_with?("%") })
  end

  test "ticking a trainer survives a reload" do
    visit_forest
    find("#{TRAINER} .pn-mm__hit").click

    assert_selector "#{TRAINER}.is-done"
    assert_selector ".pn-mm-legend__row[data-marker-id='trainer-30-33'].is-done"
    assert_selector "[data-map-markers-target='counterDone']", text: "1"

    visit FOREST

    assert_selector "#{TRAINER}.is-done"
    assert_selector "[data-map-markers-target='counterDone']", text: "1"
  end

  test "a legend row ticks the pin it names" do
    visit_forest
    find(".pn-mm-legend__row[data-marker-id='item-25-11']").click

    assert_selector ".pn-mm[data-marker-id='item-25-11'].is-done"
  end

  test "an exit raises its hint without becoming a chore" do
    visit_forest
    find(".pn-mm[data-marker-id='exit-15-47'] .pn-mm__hit").click

    assert_selector ".pn-mm[data-marker-id='exit-15-47'].is-selected"
    assert_no_selector ".pn-mm[data-marker-id='exit-15-47'].is-done"
    assert_selector "[data-map-markers-target='counterDone']", text: "0"
  end

  test "filtering shows one category and the toggle hides the labels" do
    visit_forest

    find(".pn-mm-pill[data-cat='hidden']").click
    assert_selector ".pn-mm:not(.is-filtered)", count: 2

    find(".pn-mm-pill[data-cat='all']").click
    assert_selector ".pn-mm:not(.is-filtered)", count: 12

    find(".pn-mm-toggle").click
    assert_no_selector "[data-controller='map-markers'].is-labelled"
  end

  test "a step item, a hidden item and a catchable Pokemon all tick and survive a reload" do
    visit_forest

    first(".pn-wt-item[data-progress-id]").click
    first(".pn-wt-hidden[data-progress-id]").click
    first(".pn-wt-catch[data-progress-id]").click

    assert_selector ".pn-wt-item.is-done"
    assert_selector ".pn-wt-hidden.is-done"
    assert_selector ".pn-wt-catch.is-done"

    visit FOREST

    assert_selector ".pn-wt-item.is-done"
    assert_selector ".pn-wt-hidden.is-done"
    assert_selector ".pn-wt-catch.is-done"
  end

  test "catching a Pokemon counts toward the leg's registered total" do
    visit "/walkthroughs/yellow/leg-04"
    within first(".pn-wt-oak__sub--reg") { assert_text "0" }

    first(".pn-wt-catch[data-progress-id]").click

    within first(".pn-wt-oak__sub--reg") { assert_text "1" }
  end

  test "a trainer card and its pin are one tick, from either side" do
    visit "/walkthroughs/yellow/leg-06"
    assert_selector ".pn-mm-layer.is-ready"
    card = ".pn-wt-trainer[data-progress-id='route-11/trainer-10-14']"
    pin = ".pn-mm[data-marker-id='trainer-10-14']"

    find(card).click
    assert_selector "#{card}.is-done"
    assert_selector "#{pin}.is-done"   # ticking the card lights its pin

    find("#{pin} .pn-mm__hit").click
    assert_no_selector "#{card}.is-done"   # and unticking the pin clears the card
  end

  # Route 1 has no trainers, no items and no gates. It reaches its neighbours by scrolling, and
  # those connections are the only thing it has to mark.
  test "a route that only connects still shows the way out" do
    visit "/walkthroughs/yellow/leg-01"
    assert_selector ".pn-mm-layer.is-ready", minimum: 2

    within "[data-map-markers-map-value='route-1']" do
      assert_selector ".pn-mm[data-cat='exit']", count: 2
    end
  end
end
