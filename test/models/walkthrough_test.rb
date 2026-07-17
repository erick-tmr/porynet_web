require "test_helper"

class WalkthroughTest < ActiveSupport::TestCase
  def game = Walkthrough.find!("yellow")

  test "find! returns the yellow game and raises for unknown games" do
    assert_equal "Pokémon Yellow", Walkthrough.find!("yellow").name
    assert_nil Walkthrough.find("red")
    assert_raises(ActiveRecord::RecordNotFound) { Walkthrough.find!("red") }
  end

  test "the game spans all of Kanto in contiguous order" do
    g = game
    assert_equal 49, g.locations.size
    assert_equal "pallet-town", g.locations.first.slug
    assert_equal "cerulean-cave", g.locations.last.slug
    assert_equal (1..49).to_a, g.locations.map(&:order)
    assert_equal 151, g.dex_goal
  end

  test "location! finds by slug and raises for an unknown location" do
    assert_equal "Viridian Forest", game.location!("viridian-forest").name
    assert_nil game.location("nope")
    assert_raises(ActiveRecord::RecordNotFound) { game.location!("nope") }
  end

  test "previous and following walk the order and stop at the ends" do
    g = game
    assert_nil g.previous(g.locations.first)
    assert_equal "route-1", g.following(g.locations.first).slug
    assert_nil g.following(g.locations.last)
    assert_equal "route-2", g.previous(g.location!("viridian-forest")).slug
    assert_equal "pewter-city", g.following(g.location!("viridian-forest")).slug
  end

  test "obtainable and new dex counts are cumulative and de-duplicated" do
    g = game
    assert_equal 75, g.obtainable_dex.size
    assert_equal %w[025], g.new_dex_for(g.location!("pallet-town"))
    assert_empty g.new_dex_for(g.location!("route-2"))
    assert_equal 3, g.obtainable_upto(g.location!("route-1")).size
    assert_equal g.obtainable_dex.size, g.obtainable_upto(g.locations.last).size
  end

  test "starter encounters are gifts while wild encounters are catchable" do
    pallet = game.location!("pallet-town")
    pikachu = pallet.encounters.sole
    assert pikachu.gift?
    refute pikachu.wild?
    assert_equal 0, pallet.catchable_count

    forest = game.location!("viridian-forest")
    assert forest.encounters.all?(&:wild?)
    assert_equal 4, forest.catchable_count
  end

  test "the eight gym locations carry badges" do
    assert_equal %w[pewter-city cerulean-city vermilion-city celadon-city fuchsia-city saffron-city cinnabar-island viridian-gym],
      game.locations.select(&:badge?).map(&:slug)
    assert_equal "BOULDER", game.location!("pewter-city").badge
    assert_equal "EARTH", game.location!("viridian-gym").badge
  end

  test "the Yellow forest table has no wild Pikachu, Weedle or Kakuna" do
    forest_dex = game.location!("viridian-forest").dex_list
    assert_equal %w[010 011 016 017], forest_dex
    refute_includes forest_dex, "025"
    refute_includes forest_dex, "013"
  end

  test "forest steps mix items, hidden items and screenshots" do
    steps = game.location!("viridian-forest").steps
    assert_equal 5, steps.size
    assert steps[0].items?
    assert steps[0].shot?
    refute steps[0].hidden?
    assert steps[1].hidden?
    refute steps[1].items?
    refute steps[1].shot?
  end

  test "every referenced sprite dex is a three-digit string" do
    g = game
    dexes = g.oak_queue.map(&:dex)
    g.locations.each do |loc|
      dexes.concat loc.encounters.map(&:dex)
      dexes.concat loc.encounters.flat_map { |e| e.evo_line.map { |stage| stage[:dex] } }
      dexes.concat loc.trainers.flat_map { |t| t.team.map { |m| m[:dex] } }
      dexes.concat loc.oak_queue.map(&:dex)
    end
    assert dexes.any?
    dexes.each { |dex| assert_match(/\A\d{3}\z/, dex, "#{dex} should be a 3-digit sprite id") }
  end

  test "every content key resolves in both locales" do
    keys = content_keys(game)
    %i[en pt].each do |locale|
      I18n.with_locale(locale) do
        keys.each { |key| assert I18n.exists?(key), "missing #{locale}: #{key}" }
      end
    end
  end

  private

  def content_keys(game)
    keys = game.oak_queue.map(&:why_key)
    game.locations.each do |loc|
      keys << loc.note_key << loc.intro_key
      loc.steps.each do |step|
        keys << step.title_key << step.text_key
        keys.concat step.items.map(&:where_key)
        keys.concat step.hidden.map(&:where_key)
      end
      keys.concat loc.encounters.filter_map(&:tip_key)
      keys.concat loc.oak_queue.map(&:why_key)
    end
    keys
  end
end
