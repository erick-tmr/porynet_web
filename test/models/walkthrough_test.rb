require "test_helper"

class WalkthroughTest < ActiveSupport::TestCase
  def game = Walkthrough.find!("yellow")
  def loc(slug) = game.locations.find { |location| location.slug == slug }

  test "find! returns the yellow game and raises for unknown games" do
    assert_equal "Pokémon Yellow", Walkthrough.find!("yellow").name
    assert_nil Walkthrough.find("red")
    assert_raises(ActiveRecord::RecordNotFound) { Walkthrough.find!("red") }
  end

  test "the game covers the 51 Kanto stops, drawing Route 4 twice around Mt. Moon" do
    g = game
    assert_equal "pallet-town", g.locations.first.slug
    assert_equal "cerulean-cave", g.locations.last.slug
    assert_equal 151, g.dex_goal
    # 51 numbered stops (1..51); Route 4 (stop 10) wraps Mt. Moon, so it is drawn as a Mt. Moon
    # approach section (leg 3) and its east half (leg 4). That makes 52 sections over 51 numbers.
    assert_equal 52, g.locations.size
    assert_equal (1..51).to_a, g.locations.map(&:order).uniq.sort
    assert_equal %w[route-4-mt-moon route-4], g.locations.select { |loc| loc.order == 10 }.map(&:slug)
  end

  test "the location sections group into 27 ordered legs with no gaps or dupes" do
    g = game
    assert_equal 27, g.legs.size
    assert_equal (1..27).to_a, g.legs.map(&:order)
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

    # leg 04 doubles back: the routes north are the middle, the Cerulean gym is the destination
    leg4 = game.leg!("leg-04")
    assert_equal "Route 4", leg4.from
    assert_equal "Cerulean City", leg4.to
    assert_equal "Route 25", leg4.locations.last.name
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

  test "the Oak example owes every catch and level-up evolution reachable before the first gym" do
    g = game
    assert_equal 17, g.oak_example.size
    assert_equal({ dex: "025", name: "Pikachu", how: "START" }, g.oak_example.first.to_h)
    assert_equal %w[011 017], g.oak_example.select { |e| e.how == "EITHER" }.map(&:dex)
    assert_empty g.oak_example.map(&:dex) & %w[026 031 034],
      "Raichu, Nidoqueen and Nidoking need a stone or a trade, so they fall outside this window"
    assert_equal g.oak_example.map(&:dex).uniq, g.oak_example.map(&:dex)
  end

  test "the first gym location carries the leader, badge and gym name the deadline card reads" do
    stop = game.first_gym_location
    assert_equal "Pewter City", stop.name
    assert_equal "BOULDER", stop.gym.badge
    assert_equal "Pewter Gym", stop.gym.name
    assert_equal "brock-gen1", stop.gym.leader.sprite
  end

  test "a leg aggregates its locations' Oak queues without duplicates" do
    assert_empty game.leg!("leg-01").oak_queue, "leg 01 has nothing catchable yet (no Poke Balls)"
    assert_equal %w[029 032 056 021 016 019], game.leg!("leg-02").oak_queue.map(&:dex)
  end

  test "the eight gym locations carry badges" do
    assert_equal %w[pewter-city cerulean-city vermilion-city celadon-city fuchsia-city saffron-city cinnabar-island viridian-gym],
      game.locations.select(&:badge?).map(&:slug)
    assert_equal %w[cinnabar-island], game.leg!("leg-12").gyms.map(&:slug)
    assert_equal %w[viridian-gym], game.leg!("leg-13").gyms.map(&:slug)
  end

  test "Pewter splits its steps around the gym, in the band" do
    pewter = loc("pewter-city")
    assert pewter.band_gym?
    refute pewter.gym_finale?
    assert_equal [ 1 ], pewter.lead_steps.map(&:n)
    assert_equal [ 2 ], pewter.after_steps.map(&:n)
    assert_empty pewter.finale_steps
  end

  test "Cerulean holds Misty back to close the leg, after the routes north" do
    cerulean = loc("cerulean-city")
    assert cerulean.gym?
    refute cerulean.band_gym?, "the gym must not render inside the Cerulean band"
    assert cerulean.gym_finale?
    assert_equal [ 1, 2, 3 ], cerulean.lead_steps.map(&:n)
    assert_empty cerulean.after_steps, "nothing renders under AFTER THE GYM any more"
    assert_equal [ 4 ], cerulean.finale_steps.map(&:n)
    assert_equal cerulean, game.leg!("leg-04").finale
    assert_nil game.leg!("leg-03").finale
  end

  test "a finale gym only sits on a multi-stop leg, where the leg page can render it" do
    assert_empty game.legs.select { |leg| leg.single? && leg.locations.any?(&:gym_finale?) }
  end

  test "Fuchsia holds Koga back until the Safari Zone has handed over Surf and the Gold Teeth" do
    fuchsia = loc("fuchsia-city")
    refute fuchsia.band_gym?, "the gym must not render before the Safari Zone band"
    assert fuchsia.gym_finale?
    assert_equal [ 1, 2, 3 ], fuchsia.lead_steps.map(&:n)
    assert_equal [ 4 ], fuchsia.finale_steps.map(&:n), "HM04 Strength lands with the gym, not before it"
    assert_equal fuchsia, game.leg!("leg-09").finale
  end

  test "Silph Co. is freed before Saffron's gym opens, as the leg-10 lead promises" do
    saffron = game.locations.index(loc("saffron-city"))
    silph = game.locations.index(loc("silph-co"))

    assert_operator silph, :<, saffron
    assert_equal 38, loc("silph-co").order
    assert_equal 39, loc("saffron-city").order
    assert_operator game.legs.index(game.leg!("silph-co")), :<, game.legs.index(game.leg!("leg-10"))
  end

  test "the Yellow forest table has no wild Pikachu, Weedle or Kakuna" do
    forest_dex = loc("viridian-forest").dex_list
    assert_equal %w[010 011 016 017], forest_dex
    refute_includes forest_dex, "025"
    refute_includes forest_dex, "013"
  end

  test "forest steps mix items, hidden items and screenshots" do
    steps = loc("viridian-forest").steps
    assert_equal 7, steps.size
    assert steps[1].hidden?
    refute steps[1].items?
    refute steps[1].shot?
    assert steps[2].items?
    assert steps[2].shot?
    refute steps[2].hidden?
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
    dexes = g.oak_example.map(&:dex)
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

  test "a location scene fills the first rival fight's where slot" do
    rival = loc("pallet-town").trainers.first
    assert rival.where.map?, "the rival's where slot should carry a location scene"
    assert_equal "walkthrough/yellow/scenes/oaks-lab-rival.png", rival.where.image

    plain = loc("route-1").trainers
    assert_empty plain
  end

  test "the seven usable in-game trades sit at their real locations" do
    by_slug = game.locations.to_h { |l| [ l.slug, l.trades ] }
    assert_equal 7, by_slug.values.sum(&:size), "Yellow has 7 usable NPC trades"
    assert_empty game.leg!("leg-01").locations.flat_map(&:trades), "leg 01 has no trades"

    mime = loc("route-2").trades.sole
    assert_equal "035", mime.give[:dex]
    assert_equal "Mr. Mime", mime.receive[:name]
    assert_equal "MILES", mime.nick

    cinnabar = loc("cinnabar-island").trades
    assert_equal %w[STICKY BUFFY CEZANNE], cinnabar.map(&:nick)
    assert_equal %w[089 112 087], cinnabar.map { |t| t.receive[:dex] }
    assert cinnabar.all? { |t| t.house.label == "WHERE" && t.inside.label == "INSIDE" }
  end

  test "every trade give and receive sprite dex is a three-digit string" do
    trades = game.locations.flat_map(&:trades)
    dexes = trades.flat_map { |t| [ t.give[:dex], t.receive[:dex] ] }
    assert_equal 14, dexes.size
    dexes.each { |dex| assert_match(/\A\d{3}\z/, dex) }
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
    refute pidgey.only, "Pidgey turns up in more than one place, so it is a ranked win"
  end

  test "best_catches tags a species with a single location as the only place to catch it" do
    bc = game.best_catches

    magikarp = bc.fetch("129")
    assert magikarp.only, "Magikarp only appears on Route 21"
    assert_equal "route-21", magikarp.slug
    assert_equal "100%", magikarp.rate, "the Old Rod hooks nothing else, so it never misses"
    assert_nil magikarp.alt_name, "there is no rival spot to compare against"

    zapdos = bc.fetch("145")
    assert zapdos.only, "Zapdos is a lone static"
    assert_equal "power-plant", zapdos.slug
    assert_nil zapdos.rate, "a static has no encounter percentage to quote"
    refute zapdos.rate?
  end

  test "best_catches skips a species whose spots cannot be ranked or called the only one" do
    bc = game.best_catches

    refute bc.key?("037"), "Vulpix is sold at the Game Corner as well as the Mansion, and coins do not rank against a rate"
    refute bc.key?("143"), "Snorlax blocks two routes, so neither one is the only place"
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

  test "a multi-floor cave breaks an encounter down by the floor it really spawns on" do
    clefairy = loc("mt-moon").encounters.find { |enc| enc.dex == "035" }

    assert clefairy.places?
    assert_equal %w[1F B1F B2F], clefairy.places.map(&:floor)
    assert_equal [ 1.2, 5.5, 10.5 ], clefairy.places.map(&:rate),
      "Clefairy is nine times likelier two floors down, which one headline rate cannot say"
    assert_equal "B2F", clefairy.best_place.floor
    assert_equal "9–13", clefairy.best_place.levels
  end

  test "the headline rate of a spread-out species is its best floor, not a hand-typed guess" do
    mt_moon = loc("mt-moon")
    clefairy = mt_moon.encounters.find { |enc| enc.dex == "035" }
    paras = mt_moon.encounters.find { |enc| enc.dex == "046" }

    assert_equal "11%", clefairy.rate, "rounded from B2F's 10.5%, so parse_rate can still read it"
    assert_equal 11, Walkthrough::Yellow.parse_rate(clefairy.rate)
    assert_equal "9–13", clefairy.level, "the level band across every floor it lives on"
    assert_equal "15%", paras.rate
    assert_equal [ "B1F", "B2F" ], paras.places.map(&:floor), "Paras is not on 1F at all"
  end

  test "a species confined to one map carries no floor breakdown to show" do
    pidgey = loc("route-1").encounters.find { |enc| enc.dex == "016" }

    refute pidgey.places?
    assert_equal "70%", pidgey.rate, "its hand-typed headline is left alone"
  end

  test "a floor's water table is read as its own place, apart from the grass on that floor" do
    seafoam = Walkthrough::Yellow.encounter_places("seafoam-islands", "072")

    assert_equal %w[B3F B4F], seafoam.select(&:surf?).map(&:floor)
    refute Walkthrough::Yellow.encounter_places("seafoam-islands", "086").any?(&:surf?),
      "Seel shares those floors but walks the grass"
  end

  test "a species carries every way it is caught at a stop, surf and rods included" do
    staryu = Walkthrough::Yellow.encounter_places("seafoam-islands", "120")

    assert_equal [ "water", "super_rod" ], staryu.map(&:kind).uniq,
      "Staryu is both Surfed into and fished up on the same floors"
    assert_equal %w[B3F B3F B4F B4F], staryu.map(&:floor).sort
    assert staryu.select(&:rod?).all? { |place| place.rate == 40.2 }
  end

  test "the rods carry the game's own odds, not a flat split" do
    magikarp = Walkthrough::Yellow.encounter_places("fuchsia-city", "129")

    old_rod = magikarp.find { |place| place.kind == "old_rod" }
    assert_equal 100.0, old_rod.rate, "the Old Rod only ever hooks Magikarp"
    assert_equal "5", old_rod.levels
    assert_equal 89.5, magikarp.find { |place| place.kind == "super_rod" }.rate,
      "three of Fuchsia's four Super Rod slots are Magikarp, weighted 39.8/29.7/19.9"
    assert_equal 10.5, Walkthrough::Yellow.encounter_places("fuchsia-city", "130").sole.rate,
      "Gyarados sits in the rarest slot"
  end

  test "a method tag matches the game table it claims to read" do
    mistagged = game.locations.flat_map do |loc|
      loc.encounters.select(&:wild?).reject { |enc| enc.places.empty? }
        .reject { |enc| enc.places.any? { |place| place.method?(enc.how) } }
        .map { |enc| "#{loc.slug}/#{enc.name} tagged #{enc.how}" }
    end

    assert_empty mistagged,
      "every wild card with a game table must be tagged with the method that table is read from"
  end

  test "the headline is made true for the card's own method, leaving other methods to the list" do
    tentacool = loc("route-21").encounters.find { |enc| enc.dex == "072" }

    assert_equal "SURF", tentacool.how
    assert_equal "100%", tentacool.rate, "the Surf table, not the 59.8% Super Rod one below it"
    assert_includes tentacool.places.map(&:kind), "super_rod", "still listed as another way in"
  end

  # Every screenshot lookup in this app degrades silently: `scene_shot` and `map_shot` fall back to
  # a placeholder, and `hidden`/`later` hand a nil image straight to `r2_image_tag`, which renders a
  # broken <img> with no error. A typo'd scene name is therefore invisible without these.
  UNRENDERED_GYM_SHOTS = "the gym card and gym puzzle frames are not drawn yet"

  def declared_shots
    game.locations.flat_map do |loc|
      loc.steps.flat_map { |s| [ [ "#{loc.slug} step #{s.n}", s.shot ] ] } +
        loc.steps.flat_map { |s| s.hidden.map { |h| [ "#{loc.slug} hidden #{h.name}", h ] } } +
        loc.later.map { |l| [ "#{loc.slug} later #{l.name}", l ] } +
        loc.trainers.flat_map { |t| [ [ "#{loc.slug} where #{t.name}", t.where ],
                                      [ "#{loc.slug} battle #{t.name}", t.battle ] ] } +
        [ [ "#{loc.slug} trivia", loc.trivia&.shot ] ]
    end.reject { |_label, node| node.nil? }
  end

  test "every screenshot a step, item or trainer points at resolves to a real image" do
    unresolved = declared_shots.reject { |_label, node| node.image }.map(&:first)

    assert_empty unresolved,
      "a name that misses the manifest renders a placeholder, never an error, so it can only be caught here"
  end

  # Walks the whole page graph rather than a hand-listed set of call sites, so a new kind of shot
  # carrier is covered the day it is added.
  def every_referenced_image(node, out = [])
    case node
    when Array then node.each { |n| every_referenced_image(n, out) }
    when Hash then node.each_value { |n| every_referenced_image(n, out) }
    when Data
      out << node.image if node.respond_to?(:image) && node.image
      node.to_h.each_value { |v| every_referenced_image(v, out) }
    end
    out
  end

  test "no generated frame is left unreferenced beyond the known backlog" do
    referenced = [ game, Walkthrough::Yellow.mew_glitch ].flat_map { |r| every_referenced_image(r) }
      .map { |i| File.basename(i, ".png") }.to_set
    orphans = (Walkthrough::Yellow.manifest.fetch("scenes").keys.to_set - referenced).to_a.sort

    # Frames the generator renders that nothing points at yet. This list may only shrink: a step
    # that stops referencing its frame silently loses the picture, and that is what this catches.
    # The three that remain are superseded duplicates, not losses: each one's step now carries a
    # per-item frame generated later (mt-moon-item-moon-stone, viridian-forest-item-pok-ball,
    # viridian-forest-item-potion-*), so pointing a step back at the old frame would show the
    # worse picture. Everything else is referenced.
    assert_equal [ "mt-moon-moon-stone", "viridian-forest-poke-ball", "viridian-forest-potion" ],
      orphans
  end

  test "a step that supersedes an older frame still shows a picture" do
    superseded = { "mt-moon" => 10, "viridian-forest" => 3 }

    superseded.each do |slug, n|
      shot = game.locations.find { |loc| loc.slug == slug }.steps[n - 1].shot
      assert shot&.map?, "#{slug} step #{n} must carry the per-item frame that replaced the old one"
    end
  end

  test "every ladder number a step names exists as a chip on that location's map" do
    missing = game.locations.flat_map do |loc|
      keys = loc.area_maps.flat_map { |m| m.markers.select { |k| k.cat == "exit" }.map(&:key) }.compact
      loc.steps.flat_map { |s| I18n.t(s.text_key).scan(/pn-wt-ladder">(\d+)</).flatten }
        .uniq.reject { |n| keys.include?(n) }.map { |n| "#{loc.slug} names ladder #{n}" }
    end

    assert_empty missing, "prose says 'ladder N' but no pin wears N, so the reference points nowhere"
  end

  test "every numbered ladder in the overlay lands on a real exit" do
    overlay = JSON.parse(File.read(Rails.root.join("app/models/walkthrough/yellow_ladders.json")))
      .fetch("ladders")
    grids = game.locations.flat_map(&:area_maps)
      .to_h { |m| [ m.name, m.markers.select { |k| k.cat == "exit" }.map { |k| k.id.delete_prefix("exit-").tr("-", ",") } ] }

    stray = overlay.flat_map do |map_name, cells|
      cells.keys.reject { |cell| grids.fetch(map_name, []).include?(cell) }
        .map { |cell| "#{map_name} #{cell}" }
    end

    assert_empty stray, "a mistyped grid cell is a silent no-op in both directions"
  end

  test "a step reads from exactly one of text and text_html" do
    both = game.locations.flat_map do |loc|
      base = loc.steps.first&.text_key&.sub(/\.steps\..*/, "")
      next [] if base.nil?

      loc.steps.select { |s| I18n.exists?("#{base}.steps.#{s.n}.text") && I18n.exists?("#{base}.steps.#{s.n}.text_html") }
        .map { |s| "#{loc.slug} step #{s.n}" }
    end

    assert_empty both, "the unread key silently goes stale while the step renders the other one"
  end

  # Renumbering steps is routine here, and `pin_tick` only binds an item to a stable key when
  # exactly one map pin carries its name. Everything else falls back to a positional
  # "slug/step-N/item-i", so a reorder quietly resets a player's saved ticks. This pins the set that
  # is allowed to be positional: NPC gifts, which have no pin by design.
  test "only pinless NPC gifts fall back to a positional progress key" do
    loose = game.locations.flat_map { |l| l.steps.flat_map(&:items) }.select { |i| i.tick.nil? }

    assert_equal 20, loose.size
    assert_equal [ "Bicycle", "Bike Voucher", "Coin Case", "Exp. All", "Fossil", "Good Rod",
                   "HM01 Cut", "HM02 Fly", "HM03 Surf", "HM04 Strength", "Itemfinder",
                   "Oak's Parcel", "Old Rod", "Poké Flute", "Pokédex", "Potion", "S.S. Ticket",
                   "Super Rod", "Town Map" ], loose.map(&:name).uniq.sort
  end

  test "a step that names a ladder renders its number as the chip the map wears" do
    steps = loc("mt-moon").steps

    assert_equal "text_html", steps[2].text_key.split(".").last,
      "the ladder numbers are markup, so the step reads from an _html key"
    body = I18n.t(steps[2].text_key)
    assert_includes body, %(<span class="pn-wt-ladder">1</span>)
    assert_includes body, %(<span class="pn-wt-ladder">2</span>)

    refute_equal "text_html", steps[0].text_key.split(".").last,
      "a step with no ladder to point at stays plain text"
  end

  test "a dungeon's ladders wear the route-order number the steps call them by" do
    floors = loc("mt-moon").area_maps.to_h { |m| [ m.floor, m.markers.select { |k| k.cat == "exit" } ] }

    assert_equal({ "exit-25-15" => "1", "exit-17-11" => "3", "exit-5-5" => "5" },
      floors["1F"].select(&:key?).to_h { |k| [ k.id, k.key ] },
      "1F's three ladders all read 'Mt. Moon B1F', so only a number tells them apart")
    assert_equal %w[2 4 6 8], floors["B1F"].select(&:key?).map(&:key).sort
    assert_equal [ "7" ], floors["B2F"].select(&:key?).map(&:key)
  end

  test "a numbered ladder keeps its direction glyph on the pin" do
    ladder = loc("mt-moon").area_maps.first.markers.find { |k| k.id == "exit-25-15" }

    assert_equal "▲", ladder.glyph_or_key, "the pin still says which way it goes"
    assert_equal "1", ladder.key, "and the label and legend carry the number"
  end

  test "an unnumbered exit is left alone" do
    outside = loc("mt-moon").area_maps.first.markers.find { |k| k.id == "exit-14-35" }
    refute outside.key?, "the way you came in needs no number"
    refute loc("viridian-forest").area_maps.first.markers.any? { |k| k.cat == "exit" && k.key? },
      "a single-floor map has no ladders to disambiguate"
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
    keys = game.legs.reject(&:special).map(&:lead_key)
    game.locations.each do |loc|
      keys << loc.note_key << loc.intro_key
      loc.steps.each do |step|
        keys << step.title_key << step.text_key
        keys.concat step.items.map(&:where_key)
        keys.concat step.hidden.map(&:where_key)
      end
      keys.concat loc.encounters.filter_map(&:tip_key)
      loc.trades.each { |trade| keys.push(trade.npc_key, trade.title_key, trade.where_key, trade.note_key) }
      keys.concat loc.oak_queue.map(&:why_key)
      if loc.gym?
        keys << loc.gym.intro_key
        keys.concat loc.gym.puzzle.map(&:text_key)
      end
    end
    keys
  end
end
