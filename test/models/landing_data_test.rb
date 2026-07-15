require "test_helper"

class LandingDataTest < ActiveSupport::TestCase
  test "hero_cells builds a 48-cell grid with gaps and a cursor" do
    cells = LandingData.hero_cells

    assert_equal 48, cells.size
    assert_equal({ filled: true, cursor: false }, cells[0])
    assert_equal({ filled: false, cursor: false }, cells[7])  # skipped
    assert_equal({ filled: true, cursor: false }, cells[21])
    assert_equal({ filled: false, cursor: true }, cells[22]) # blinking cursor
    assert_equal({ filled: false, cursor: false }, cells[30])

    [ 7, 13, 19 ].each { |i| refute cells[i][:filled], "cell #{i} should be a gap" }
  end

  test "box_slots fills the first 18 slots with dex numbers, rest empty" do
    slots = LandingData.box_slots

    assert_equal 30, slots.size
    assert_equal({ filled: true, empty: false, dex: "#016" }, slots[0])
    assert_equal({ filled: true, empty: false, dex: "#052" }, slots[17])
    assert_equal({ filled: false, empty: true, dex: "#000" }, slots[18]) # fallback dex
    assert_equal({ filled: false, empty: true, dex: "#000" }, slots[29])
  end

  test "content constants stay in sync with the landing page" do
    assert_equal 6, LandingData::FEATURES.size
    assert LandingData::FEATURES.frozen?
    # feature keys map to config/locales/*.yml under pages.home.features.list
    assert_equal %i[tracker oak guides parser porypc offline],
      LandingData::FEATURES.map(&:key)

    assert_equal 6, LandingData::CITIES.size
    assert_equal "PEWTER CITY", LandingData::CITIES[LandingData::DEFAULT_CITY_INDEX].name

    assert_equal 9, LandingData::GENS.size
    assert_equal 2, LandingData::GENS.count(&:live)

    assert_equal 18, LandingData::DEX_LABELS.size
  end
end
