require "test_helper"

class WalkthroughTest < ActiveSupport::TestCase
  def game = Walkthrough.find!("yellow")
  def loc(slug) = game.locations.find { |location| location.slug == slug }

  test "find! returns the yellow game and raises for unknown games" do
    assert_equal "Pokémon Yellow", Walkthrough.find!("yellow").name
    assert_nil Walkthrough.find("red")
    assert_raises(ActiveRecord::RecordNotFound) { Walkthrough.find!("red") }
  end

  test "the game spans all 51 Kanto locations in contiguous order" do
    g = game
    assert_equal 51, g.locations.size
    assert_equal "pallet-town", g.locations.first.slug
    assert_equal "cerulean-cave", g.locations.last.slug
    assert_equal (1..51).to_a, g.locations.map(&:order)
    assert_equal 151, g.dex_goal
  end

  test "the 51 locations group into 26 ordered legs with no gaps or dupes" do
    g = game
    assert_equal 26, g.legs.size
    assert_equal (1..26).to_a, g.legs.map(&:order)
    covered = g.legs.flat_map { |l| l.locations.map(&:slug) }
    assert_equal g.locations.map(&:slug).sort, covered.sort
    assert_equal covered.size, covered.uniq.size
  end

  test "leg! finds by slug and raises for an unknown leg" do
    leg = game.leg!("leg-01")
    assert_equal %w[pallet-town route-1], leg.locations.map(&:slug)
    refute leg.special
    assert_nil game.leg("nope")
    assert_raises(ActiveRecord::RecordNotFound) { game.leg!("nope") }
  end

  test "special legs wrap a single dungeon location" do
    leg = game.leg!("viridian-forest")
    assert leg.special
    assert leg.single?
    assert_equal "Viridian Forest", leg.locations.sole.name
  end

  test "leg titles read from and to, single legs collapse to one name" do
    leg1 = game.leg!("leg-01")
    assert_equal "Pallet Town", leg1.from
    assert_equal "Route 1", leg1.to
    refute leg1.single?
    assert game.leg!("leg-06").single?
  end

  test "leg_before and leg_after walk the legs and stop at the ends" do
    g = game
    assert_nil g.leg_before(g.legs.first)
    assert_equal "leg-02", g.leg_after(g.leg!("leg-01")).slug
    assert_nil g.leg_after(g.legs.last)
  end

  test "leg stats aggregate catch counts, new dex and obtainable" do
    g = game
    leg1 = g.leg!("leg-01")
    assert_equal 2, leg1.catch_count
    assert_equal %w[025 016 019], g.new_dex_for_leg(leg1)
    assert_equal 3, g.obtainable_upto_leg(leg1).size
    assert_equal 83, g.obtainable_dex.size
    assert_operator g.obtainable_upto_leg(g.leg!("viridian-forest")).size, :>, 3
  end

  test "a leg aggregates its locations' Oak queues without duplicates" do
    assert_empty game.leg!("leg-01").oak_queue, "leg 01 has nothing catchable yet (no Poke Balls)"
    assert_equal %w[029 032 056 021 016 019], game.leg!("leg-02").oak_queue.map(&:dex)
  end

  test "the eight gym locations carry badges" do
    assert_equal %w[pewter-city cerulean-city vermilion-city celadon-city fuchsia-city saffron-city cinnabar-island viridian-gym],
      game.locations.select(&:badge?).map(&:slug)
    assert_equal %w[cinnabar-island viridian-gym], game.leg!("leg-12").gyms.map(&:slug)
  end

  test "the Yellow forest table has no wild Pikachu, Weedle or Kakuna" do
    forest_dex = loc("viridian-forest").dex_list
    assert_equal %w[010 011 016 017], forest_dex
    refute_includes forest_dex, "025"
    refute_includes forest_dex, "013"
  end

  test "forest steps mix items, hidden items and screenshots" do
    steps = loc("viridian-forest").steps
    assert_equal 5, steps.size
    assert steps[0].items?
    assert steps[0].shot?
    refute steps[0].hidden?
    assert steps[1].hidden?
    refute steps[1].items?
    refute steps[1].shot?
  end

  test "starter encounters are gifts while wild encounters are catchable" do
    pallet = loc("pallet-town")
    pikachu = pallet.encounters.sole
    assert pikachu.gift?
    refute pikachu.wild?
    assert_equal 0, pallet.catchable_count

    forest = loc("viridian-forest")
    assert forest.encounters.all?(&:wild?)
    assert_equal 4, forest.catchable_count
  end

  test "every referenced sprite dex is a three-digit string" do
    g = game
    dexes = g.oak_queue.map(&:dex)
    g.locations.each do |l|
      dexes.concat l.encounters.map(&:dex)
      dexes.concat l.encounters.flat_map { |e| e.evo_line.map { |stage| stage[:dex] } }
      dexes.concat l.trainers.flat_map { |t| t.team.map { |m| m[:dex] } }
      dexes.concat l.oak_queue.map(&:dex)
    end
    assert dexes.any?
    dexes.each { |dex| assert_match(/\A\d{3}\z/, dex, "#{dex} should be a 3-digit sprite id") }
  end

  test "every trainer, item and hidden item carries a sprite slug" do
    g = game
    steps = g.locations.flat_map(&:steps)
    assert g.locations.flat_map(&:trainers).all?(&:sprite), "every trainer needs a VS sprite"
    assert steps.flat_map(&:items).all?(&:sprite), "every item needs a sprite"
    assert steps.flat_map(&:hidden).all?(&:sprite), "every hidden item needs a sprite"
  end

  test "the rival Blue's VS sprite advances from young to champion" do
    blues = game.locations.flat_map(&:trainers).select { |t| t.name == "Blue" }
    assert_equal %w[blue-gen1 blue-gen1champion blue-gen1two], blues.map(&:sprite).uniq.sort
    assert_equal "blue-gen1", blues.first.sprite
    assert_equal "blue-gen1champion", blues.last.sprite
  end

  test "a battle scene fills the first rival fight's where slot" do
    rival = loc("pallet-town").trainers.first
    assert rival.where.map?, "the rival's where slot should carry a battle scene"
    assert_equal "walkthrough/yellow/battles/battle-rival-oaks-lab.png", rival.where.image

    plain = loc("route-1").trainers
    assert_empty plain
  end

  test "scene_shot returns a placeholder for an unknown scene key" do
    missing = Walkthrough::Yellow.scene_shot("no-such-scene", "VS")
    refute missing.map?
    assert_nil missing.image
  end

  test "route 1 step 1 shows the tall-grass direction shot" do
    shot = loc("route-1").steps.first.shot
    assert shot.map?
    assert_equal "walkthrough/yellow/scenes/route-1-north.png", shot.image
  end

  test "item sprites derive from the name and override for TMs" do
    assert_equal "poke-ball", Walkthrough::Yellow.item_sprite("Poké Ball")
    assert_equal "tm-normal", Walkthrough::Yellow.item_sprite("TM34 Bide")
  end

  test "every gym city carries a dedicated gym with leader, badge and TM" do
    g = game
    assert_equal 8, g.locations.count(&:gym?)
    assert_equal g.locations.select(&:badge?), g.locations.select(&:gym?)

    brock = loc("pewter-city").gym
    assert_equal "ROCK", brock.type
    assert_equal "Brock", brock.leader.name
    assert_equal "BOULDER", brock.badge
    assert_equal "walkthrough/yellow/badges/boulder.png", brock.badge_img
    assert brock.trainers?
    refute brock.puzzle?

    surge = loc("vermilion-city").gym
    assert surge.puzzle?
    assert_equal 3, surge.puzzle.size
    assert surge.puzzle[1].shot?
    refute surge.puzzle[0].shot?
  end

  test "every content and leg key resolves in both locales" do
    keys = content_keys(game)
    %i[en pt].each do |locale|
      I18n.with_locale(locale) do
        keys.each { |key| assert I18n.exists?(key), "missing #{locale}: #{key}" }
      end
    end
  end

  test "best_catches picks the top rate and breaks ties by earliest location" do
    bc = game.best_catches
    pidgey = bc.fetch("016")
    assert_equal "route-1", pidgey.slug
    assert_equal "70%", pidgey.rate
    refute pidgey.tie
    assert_equal "Route 5", pidgey.alt_name
    assert_equal "40%", pidgey.alt_rate

    rattata = bc.fetch("019")
    assert_equal "route-2", rattata.slug
    assert rattata.tie, "Rattata's 35% is matched elsewhere, so the earliest location wins"

    refute bc.key?("025"), "Pikachu is a gift, not a rated wild catch"
    refute bc.key?("145"), "Zapdos is a lone static"
    refute bc.key?("129"), "Magikarp only appears on Route 21, so there is no choice to rank"
  end

  test "best_catch_here flags only the winning location for a species" do
    g = game
    r1 = loc("route-1")
    r2 = loc("route-2")
    pidgey_r1 = r1.encounters.find { |e| e.dex == "016" }
    pidgey_r2 = r2.encounters.find { |e| e.dex == "016" }
    assert g.best_catch_here(r1, pidgey_r1), "Route 1 is Pidgey's best spot"
    assert_nil g.best_catch_here(r2, pidgey_r2), "Route 2 is not Pidgey's best spot"
  end

  test "locations carry plain rendered area maps" do
    g = game
    vf = loc("viridian-forest")
    assert_equal 1, vf.area_maps.size
    assert_equal "walkthrough/yellow/maps/viridian-forest.png", vf.area_maps.first.image
    refute vf.area_maps.first.floor?

    floors = loc("mt-moon").area_maps
    assert_equal %w[1F B1F B2F], floors.map(&:floor)
    assert floors.first.floor?
    assert(g.locations.count(&:area_maps?) > 40)
  end

  test "an interior map fills a step's screenshot slot" do
    steps = loc("pallet-town").steps
    assert steps.first.shot.map?
    assert_equal "walkthrough/yellow/maps/reds-house-2f.png", steps.first.shot.image

    exit_shot = steps[3].shot
    assert exit_shot.map?
    assert_equal "walkthrough/yellow/scenes/pallet-town-exit.png", exit_shot.image

    plain = Walkthrough::Yellow.map_shot("route-2", 1, "STEP 1")
    refute plain.map?
    assert_nil plain.image
  end

  private

  def content_keys(game)
    keys = game.oak_queue.map(&:why_key)
    keys.concat game.legs.reject(&:special).map(&:lead_key)
    game.locations.each do |loc|
      keys << loc.note_key << loc.intro_key
      loc.steps.each do |step|
        keys << step.title_key << step.text_key
        keys.concat step.items.map(&:where_key)
        keys.concat step.hidden.map(&:where_key)
      end
      keys.concat loc.encounters.filter_map(&:tip_key)
      keys.concat loc.oak_queue.map(&:why_key)
      if loc.gym?
        keys << loc.gym.intro_key
        keys.concat loc.gym.puzzle.map(&:text_key)
      end
    end
    keys
  end
end
