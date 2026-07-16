require "test_helper"

class LandingDataTest < ActiveSupport::TestCase
  test "hero_cells builds a 48-cell grid with gaps, a cursor and sprites" do
    cells = LandingData.hero_cells

    assert_equal 48, cells.size
    assert_equal({ filled: true, cursor: false, sprite: "001" }, cells[0])
    assert_equal({ filled: false, cursor: false, sprite: "008" }, cells[7])  # skipped
    assert_equal({ filled: true, cursor: false, sprite: "022" }, cells[21])
    assert_equal({ filled: false, cursor: true, sprite: "023" }, cells[22]) # blinking cursor
    assert_equal({ filled: false, cursor: false, sprite: "031" }, cells[30])

    [ 7, 13, 19 ].each { |i| refute cells[i][:filled], "cell #{i} should be a gap" }
  end

  test "box_slots fills the first 18 slots with dex numbers and sprites, rest empty" do
    slots = LandingData.box_slots

    assert_equal 30, slots.size
    assert_equal({ filled: true, empty: false, dex: "#016", sprite: "016" }, slots[0])
    assert_equal({ filled: true, empty: false, dex: "#052", sprite: "052" }, slots[17])
    assert_equal({ filled: false, empty: true, dex: "#000", sprite: nil }, slots[18]) # fallback dex
    assert_equal({ filled: false, empty: true, dex: "#000", sprite: nil }, slots[29])
  end

  test "content constants stay in sync with the landing page" do
    assert_equal 6, LandingData::FEATURES.size
    assert LandingData::FEATURES.frozen?
    assert_equal %i[tracker oak guides parser porypc offline],
      LandingData::FEATURES.map(&:key)

    assert_equal 6, LandingData::CITIES.size
    assert_equal "PEWTER CITY", LandingData::CITIES[LandingData::DEFAULT_CITY_INDEX].name

    pallet = LandingData::CITIES.first
    assert_equal [ "Bulbasaur", "Charmander", "Squirtle" ], pallet.new_mons.map { |mon| mon[:name] }
    assert_equal({ name: "Bulbasaur", dex: "001" }, pallet.new_mons.first)
    LandingData::CITIES.flat_map(&:new_mons).each do |mon|
      assert_match(/\A\d{3}\z/, mon[:dex], "#{mon[:name]} should map to a 3-digit sprite")
    end

    assert_equal 9, LandingData::GENS.size
    assert_equal 2, LandingData::GENS.count(&:live)

    assert_equal 18, LandingData::DEX_LABELS.size
  end
end
