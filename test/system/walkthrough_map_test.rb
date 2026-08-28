require "application_system_test_case"

class WalkthroughMapTest < ApplicationSystemTestCase
  FOREST = "/walkthroughs/yellow/viridian-forest".freeze
  TRAINER = ".pn-mm[data-marker-id='trainer-30-33']".freeze

  def visit_forest
    visit FOREST
    assert_selector ".pn-mm-layer.is-ready"
  end

  # Click something after centering it, well clear of any edge. Cuprite scrolls an element into
  # view and then clicks a computed point, so a pin parked at the very edge of a tall map would
  # otherwise sit under its frame's clip and swallow the click.
  #
  # The map arriving from R2 used to grow its frame and shove everything below it down the page,
  # which is what the second centring below is for. The image now carries its own width and height,
  # so the canvas holds that space from the first paint and nothing below it moves.
  def click_centered(selector)
    node = find(selector)
    centre(node)
    settle_network
    centre(node)
    node.click
  end

  # Best effort, and never the thing that fails a test. These pages ask R2 for thirty-odd sprites,
  # which can outlast any cap worth setting, and a wait that raises when they do is one more way
  # for a green change to come back red. Now that the map reserves its own space there is nothing
  # left in flight that can move a target, so a slow fetch is just a slow fetch.
  def settle_network
    page.driver.browser.network.wait_for_idle(timeout: Capybara.default_max_wait_time)
  rescue Ferrum::PendingConnectionsError
    nil
  end

  def centre(node)
    node.evaluate_script("this.scrollIntoView({ block: 'center', inline: 'center' })")
  end

  test "the map draws a marker for everything the game data holds" do
    visit_forest

    assert_selector ".pn-mm", count: 12
    assert_selector ".pn-mm-legend__row", count: 12
    assert_selector ".pn-mm-legend__chip", text: "T1"
  end

  test "markers are placed from their own coordinates, not stacked in a corner" do
    visit_forest

    spots = page.all(".pn-mm").map do |marker|
      marker.evaluate_script("[this.style.getPropertyValue('--mx'), this.style.getPropertyValue('--my')]")
    end

    assert_equal 12, spots.uniq.size, "no two markers should share a spot"
    assert(spots.flatten.all? { |offset| offset.end_with?("%") })
  end

  test "ticking a trainer survives a reload" do
    visit_forest
    click_centered("#{TRAINER} .pn-mm__hit")

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
    click_centered(".pn-mm[data-marker-id='exit-15-47'] .pn-mm__hit")

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

  # Registration is a Pokédex fact, not a per-stop one. Viridian lists Magikarp behind an Old Rod
  # you do not own for another four legs, and that card used to drop out of the progress system
  # entirely: it could not be ticked and never showed the tick the section header was already
  # counting.
  MAGIKARP = ".pn-wt-catch[data-progress-id='129']".freeze

  test "a species caught at one stop reads as caught on every other stop that lists it" do
    visit "/walkthroughs/yellow/leg-05"
    first(MAGIKARP).click
    assert_selector "#{MAGIKARP}.is-done"

    visit "/walkthroughs/yellow/leg-02"

    # Viridian's locked Old Rod card shows the same catch the section header was already counting.
    assert_selector "#{MAGIKARP}.is-done"
    assert_selector ".pn-wt-catchsec__tally", text: "1 / 1 CAUGHT"
  end

  test "a card the stop cannot catch yet still counts bodies in Living Dex mode" do
    visit_with_modes "/walkthroughs/yellow/leg-02", "living"

    card = "#catchsec-viridian-city-old-rod-body #{MAGIKARP}"
    find("#{card} .pn-wt-stepper__btn--add").click

    within(find("#{card} .pn-wt-stepper__count")) { assert_text "1" }
    # The first body registers the species, so every other card for it ticks too.
    assert_selector "#{MAGIKARP}.is-done", count: 2
  end

  # The tick and the LOCKED badge share the card's top-right corner, so collecting an item has to
  # take the badge down with it. An item you are holding is not locked any more, whether you ticked
  # it here or on the stop that finally walks to it.
  test "a locked item that has been collected stops calling itself locked" do
    visit "/walkthroughs/yellow/leg-02"
    card = ".pn-wt-later[data-progress-id='route-2/item-13-54']"

    assert_selector "#{card} .pn-wt-later__lock"
    assert_no_selector "#{card} .pn-wt-later__check", visible: true

    find(card).click

    assert_selector "#{card}.is-done"
    assert_selector "#{card} .pn-wt-later__check", visible: true
    assert_no_selector "#{card} .pn-wt-later__lock", visible: true
  end

  test "catching a Pokemon moves the window's registered count, remainder and meter together" do
    visit_with_modes "/walkthroughs/yellow/leg-04", "oak"

    within(first(".pn-wt-statbar__num--green")) { assert_text "0" }
    owed = first(".pn-wt-statbar__num--amber").text.to_i

    first(".pn-wt-catch[data-progress-id]").click

    within(first(".pn-wt-statbar__num--green")) { assert_text "1" }
    within(first(".pn-wt-statbar__num--amber")) { assert_text (owed - 1).to_s }
    assert_selector "[data-meter-pct]", text: /%/
  end

  test "a challenge section opens on its lists and folds them away on demand" do
    visit_with_modes "/walkthroughs/yellow/leg-04", "living", "oak"

    assert_selector ".pn-wt-ld .pn-wt-statbar"
    assert_selector ".pn-wt-oak__window"
    assert_selector ".pn-wt-ldrow"
    assert_selector ".pn-wt-oaktile"

    find(".pn-wt-oak .pn-wt-fold").click
    assert_no_selector ".pn-wt-oaktile", visible: true
    assert_selector ".pn-wt-ldrow", visible: true

    find(".pn-wt-ld .pn-wt-fold").click
    assert_no_selector ".pn-wt-ldrow", visible: true

    find(".pn-wt-ld .pn-wt-fold").click
    assert_selector ".pn-wt-ldrow"
  end

  test "a folded catchable section is still folded on the next visit" do
    section = "#catchsec-viridian-forest-grass"
    visit_forest

    assert_selector "#{section}.is-ready.is-open"
    assert_selector "#{section} .pn-wt-catch", count: 4

    click_centered("#{section} .pn-wt-catchsec__head")
    assert_no_selector "#{section} .pn-wt-catch", visible: true

    visit FOREST

    assert_selector "#{section}.is-ready"
    assert_no_selector "#{section} .pn-wt-catch", visible: true

    click_centered("#{section} .pn-wt-catchsec__head")
    assert_selector "#{section} .pn-wt-catch", count: 4
  end

  test "the Living Dex stepper counts bodies and registers the species on the first one" do
    visit_with_modes "/walkthroughs/yellow/viridian-forest", "living"

    card = ".pn-wt-catch[data-body-counter-dex-value='011']"
    row = ".pn-wt-ldrow[data-body-counter-dex-value='011']"
    within(find("#{card} .pn-wt-stepper__count")) { assert_text "0" }

    find("#{card} .pn-wt-stepper__btn--add").click
    within(find("#{card} .pn-wt-stepper__count")) { assert_text "1" }
    within(find("#{row} .pn-wt-ldrow__prog")) { assert_text "1 / 2" }

    find("#{card} .pn-wt-stepper__btn--add").click
    assert_selector "#{card}.is-met"
    assert_selector "#{row}.is-met"

    # The quota is what the walkthrough asks for, not a ceiling: a collector can bank spares, so
    # the third body counts and the row stays met rather than clamping at 2.
    find("#{card} .pn-wt-stepper__btn--add").click
    within(find("#{card} .pn-wt-stepper__count")) { assert_text "3" }
    assert_selector "#{card}.is-met"
    assert_selector "#{row}.is-met"

    assert_selector ".pn-wt-ldstage[data-progress-id='011'].is-done"
  end

  test "ticking a card caught fills its body in the Living Dex queue, and un-ticking clears it" do
    visit_with_modes "/walkthroughs/yellow/leg-01", "living"

    card = ".pn-wt-catch[data-body-counter-dex-value='025']"
    row = ".pn-wt-ldrow[data-body-counter-dex-value='025']"
    within(find("#{row} .pn-wt-ldrow__prog")) { assert_text "0 / 1" }

    find(card).click

    assert_selector "#{card}.is-done"
    assert_selector "#{row}.is-met"
    assert_selector "#{row} .pn-wt-ldrow__met", text: "QUOTA MET ✓"

    find(card).click

    assert_no_selector "#{row}.is-met"
    within(find("#{row} .pn-wt-ldrow__prog")) { assert_text "0 / 1" }
  end

  # A quota on a card is a decision, so the card has to carry the reason for it: one Pidgey here,
  # because Route 13 hands out the Pidgeotto that fills the two stages above it. With Living Dex
  # off there is no quota to explain, so the line goes away with the rest of the mode.
  test "a catch card names the stage above its quota, and drops the line when the mode is off" do
    visit_with_modes "/walkthroughs/yellow/leg-01", "living"

    card = ".pn-wt-catch[data-body-counter-dex-value='016']"

    assert_selector "#{card} .pn-wt-catchbadge--living", text: "LIVING DEX ×1"
    assert_selector "#{card} .pn-wt-catch__later-text",
      text: "Route 13 has Pidgeotto at 15%, so one Pidgey is all the line asks for."

    visit_with_modes "/walkthroughs/yellow/leg-01"

    assert_selector card
    assert_no_selector "#{card} .pn-wt-catch__later-text"
  end

  test "a body registers the species, and stepping again never un-registers it" do
    visit_with_modes "/walkthroughs/yellow/viridian-forest", "living"

    card = ".pn-wt-catch[data-body-counter-dex-value='010']"
    find("#{card} .pn-wt-stepper__btn--add").click

    assert_selector "#{card}.is-met"
    assert_selector "#{card}.is-done"

    find("#{card} .pn-wt-stepper__btn--add").click

    assert_selector "#{card}.is-done"
    # A second body past a quota of one still counts, and never un-registers the species.
    within(find("#{card} .pn-wt-stepper__count")) { assert_text "2" }
  end

  test "a trainer card and its pin are one tick, from either side" do
    visit "/walkthroughs/yellow/leg-06"
    assert_selector ".pn-mm-layer.is-ready"
    card = ".pn-wt-trainer[data-progress-id='route-11/trainer-10-14']"
    pin = ".pn-mm[data-marker-id='trainer-10-14']"

    find(card).click
    assert_selector "#{card}.is-done"
    assert_selector "#{pin}.is-done"

    click_centered("#{pin} .pn-mm__hit")
    assert_no_selector "#{card}.is-done"
  end

  test "a route that only connects still shows the way out" do
    visit "/walkthroughs/yellow/leg-01"
    assert_selector ".pn-mm-layer.is-ready", minimum: 2

    within "[data-map-markers-map-value='route-1']" do
      assert_selector ".pn-mm[data-cat='exit']", count: 2
    end
  end

  test "a wide route takes the landscape template and holds its map at native width" do
    visit "/walkthroughs/yellow/leg-03"
    assert_selector ".pn-mm-layer.is-ready", minimum: 2

    assert_selector ".pn-mm-block[data-map-markers-map-value='route-3'][data-map-orient='landscape']"
    assert_selector ".pn-mm-block[data-map-markers-map-value='pewter-city'][data-map-orient='portrait']"

    within ".pn-mm-block[data-map-markers-map-value='route-3']" do
      assert_selector ".pn-mm-howto--top"                    # the how-to moves above the map
      assert_selector ".pn-mm-howto--side", visible: :hidden # its side copy is hidden
      assert_equal "1120px",
        find(".pn-mm-canvas").evaluate_script("this.style.getPropertyValue('--mm-native-w')")
    end
  end

  test "a section with several floor maps shows the how-to only on the first" do
    visit "/walkthroughs/yellow/mt-moon"
    assert_selector ".pn-mm-layer.is-ready", minimum: 2
    assert_operator all(".pn-mm-block").size, :>, 1, "Mt. Moon has several floor maps"

    assert_selector ".pn-mm-howto--top", count: 1, visible: :all
    assert_selector ".pn-mm-howto--side", count: 1, visible: :all
    assert_no_selector ".pn-mm-block:not(:first-child) .pn-mm-howto", visible: :all
  end

  test "an important NPC raises a hint but never becomes a chore" do
    visit "/walkthroughs/yellow/leg-01"
    assert_selector ".pn-mm-layer.is-ready", minimum: 2
    npc = ".pn-mm[data-marker-id='npc-technology']"

    within ".pn-mm-block[data-map-markers-map-value='pallet-town']" do
      assert_selector ".pn-mm-legend__chip--npc", text: "N1"
      click_centered("#{npc} .pn-mm__hit")

      assert_selector "#{npc}.is-selected"
      assert_no_selector "#{npc}.is-done"
    end
  end
end
