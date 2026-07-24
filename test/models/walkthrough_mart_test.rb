require "test_helper"

class WalkthroughMartTest < ActiveSupport::TestCase
  def game = Walkthrough.find!("yellow")

  def location(slug) = game.locations.find { |loc| loc.slug == slug }

  test "the item catalog is read once and frozen" do
    first = Walkthrough::Yellow.item_catalog

    assert_same first, Walkthrough::Yellow.item_catalog
    assert_predicate first, :frozen?
  end

  test "a city mart lists its stock priced and pictured from the catalog" do
    mart = location("viridian-city").mart

    refute_predicate mart, :multi?
    assert_equal 5, mart.count
    ball = mart.counters.first.items.first
    assert_equal "Poké Ball", ball.name
    assert_equal "poke-ball", ball.sprite
    assert_equal 200, ball.price
    assert_predicate ball, :rec?
  end

  test "an item the game spells oddly still finds its sprite and description" do
    parlyz = location("viridian-city").mart.counters.first.items.find { |i| i.name == "Parlyz Heal" }

    assert_equal "paralyze-heal", parlyz.sprite
    assert_equal "walkthrough.ui.mart_items.paralyze_heal", parlyz.desc_key
  end

  test "every mart city and only those carry a mart" do
    with_mart = game.locations.select(&:mart?).map(&:slug)

    assert_equal %w[celadon-city cerulean-city cinnabar-island fuchsia-city lavender-town
                    pewter-city saffron-city vermilion-city viridian-city].sort, with_mart.sort
    refute_predicate location("route-1"), :mart?
  end

  test "the Celadon store is a six-floor department store" do
    store = location("celadon-city").mart

    assert_predicate store, :multi?
    assert_equal %w[1F 2F 3F 4F 5F ROOF], store.floors.map(&:label)
    assert_equal 9, store.tm_count
    assert_equal 4, store.stone_count
    assert_equal 9800, store.priciest
  end

  test "a sold TM carries its number, move and type-picked sprite" do
    tm_counter = location("celadon-city").mart.floors.find { |f| f.label == "2F" }.counters.last
    take_down = tm_counter.items.find { |i| i.move == "Take Down" }

    assert_predicate take_down, :tm?
    assert_equal "TM09 · Take Down", take_down.label
    assert_equal "tm-normal", take_down.sprite
    assert_equal 3000, take_down.price
  end

  test "the free TV-game-shop TM is a gift with its own written blurb" do
    gift = location("celadon-city").mart.floors.find { |f| f.label == "3F" }.gift

    assert_equal "TM18 · Counter", gift.label
    assert_equal "walkthrough.yellow.locations.celadon_city.store.floors.3F.gift_desc", gift.desc_key
  end

  test "the rooftop trades a drink for a TM" do
    roof = location("celadon-city").mart.floors.find { |f| f.label == "ROOF" }
    ice = roof.trades.find { |t| t.drink == "Fresh Water" }

    assert_equal "TM13", ice.tm_short
    assert_equal "Ice Beam", ice.move
    assert_equal "tm-ice", ice.tm_sprite
  end

  test "a plain sold TM describes the move type it teaches, a described item its own blurb" do
    tm = Walkthrough::Yellow.mart_item("TM Take Down")
    item = Walkthrough::Yellow.mart_item("Potion")

    I18n.with_locale(:en) do
      assert_equal "Normal-type move.", ApplicationController.helpers.mart_item_desc(tm)
      assert_equal "Restores 20 HP.", ApplicationController.helpers.mart_item_desc(item)
    end
  end

  test "every mart's stock and every store item has copy in both locales" do
    items = game.locations.filter_map(&:mart).flat_map do |mart|
      (mart.counters + mart.floors.flat_map(&:counters)).flat_map(&:items) +
        mart.floors.filter_map(&:gift)
    end

    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        items.each { |item| assert_not_empty ApplicationController.helpers.mart_item_desc(item) }
      end
    end
  end
end
