require "test_helper"

class WalkthroughTest < ActiveSupport::TestCase
  def game = Walkthrough.find!("yellow")
  def loc(slug) = game.locations.find { |location| location.slug == slug }

  test "find! returns the yellow game and raises for unknown games" do
    assert_equal "Pokémon Yellow", Walkthrough.find!("yellow").name
    assert_nil Walkthrough.find("red")
    assert_raises(ActiveRecord::RecordNotFound) { Walkthrough.find!("red") }
  end

  test "the game covers the 52 Kanto stops, drawing six of them twice" do
    g = game
    assert_equal "pallet-town", g.locations.first.slug
    assert_equal "cerulean-cave", g.locations.last.slug
    assert_equal 151, g.dex_goal
    # 53 numbered stops (1..53), six of them walked twice: Route 4 (stop 10) wraps Mt. Moon,
    # Vermilion (stop 17) is split around the S.S. Anne, which is what hands over the Cut its gym
    # needs, Route 10 (stop 22) is cut in half by Rock Tunnel, Celadon (stop 28) is left and come
    # back to so the Rocket Hideout is cleared before Erika, Fuchsia (stop 35) is left and come
    # back to so the Safari Zone hands over the Gold Teeth before Koga, Route 16 (stop 37) is
    # dipped into early for Fly and walked properly at Cycling Road, and Saffron (stop 41) is
    # arrived at and come back to because its gym stays Rocket-held until Silph is cleared. Each
    # pass is its own section, so 61 sections share 53 numbers: the odd one is the Surf sweep,
    # which owns no stop of its own and borrows the five maps it walks onto.
    assert_equal 61, g.locations.size
    assert_equal (1..53).to_a, g.locations.map(&:order).uniq.sort
    assert_equal %w[route-4-mt-moon route-4], g.locations.select { |loc| loc.order == 10 }.map(&:slug)
    assert_equal %w[vermilion-city vermilion-city-return],
      g.locations.select { |loc| loc.order == 17 }.map(&:slug)
    assert_equal %w[route-10 route-10-south], g.locations.select { |loc| loc.order == 22 }.map(&:slug)
    assert_equal %w[celadon-city celadon-city-return],
      g.locations.select { |loc| loc.order == 28 }.map(&:slug)
    assert_equal %w[fuchsia-city fuchsia-city-return],
      g.locations.select { |loc| loc.order == 35 }.map(&:slug)
    assert_equal %w[route-16-fly route-16], g.locations.select { |loc| loc.order == 37 }.map(&:slug)
  end

  test "both passes of a stop walked twice list the same water" do
    first, second = %w[vermilion-city vermilion-city-return].map { |slug| loc(slug) }
    water = ->(l) { l.wild_encounters.map { |enc| [ enc.how, enc.dex, enc.rate ] } }

    assert_equal water.call(first), water.call(second)
    assert_equal [ "007" ], second.encounters.reject(&:wild?).map(&:dex)
    refute_includes game.best_catches.values.map(&:slug), "vermilion-city-return",
      "the second pass must never win the star over the first"
  end

  test "the location sections group into 31 ordered legs with no gaps or dupes" do
    g = game
    assert_equal 31, g.legs.size
    assert_equal (1..31).to_a, g.legs.map(&:order)
    covered = g.legs.flat_map { |l| l.locations.map(&:slug) }
    assert_equal g.locations.map(&:slug).sort, covered.sort
    assert_equal covered.size, covered.uniq.size
  end

  # Both birds are taken where the walk already goes. The Surf sweep ends on the plant's own
  # doorstep, and the Seafoam cave runs under the islands that split Route 20, so walking in at the
  # east mouth and out at the west one is the way to Cinnabar rather than a detour off it. The stop
  # numbers run with the walk, so moving either renumbers everything between.
  test "Seafoam is walked in passing on Route 20, and the Power Plant off the sweep that reaches it" do
    tail = game.legs.map(&:slug).drop_while { |slug| slug != "leg-14" }

    assert_equal %w[leg-14 seafoam-islands leg-15 leg-16 victory-road leg-17 indigo-plateau
                    cerulean-cave], tail
    assert_equal "power-plant", game.legs[game.legs.index(game.leg!("leg-13")) + 1].slug,
      "the sweep ends on the plant's own doorstep, so the plant is the page after it"
    assert_equal [ 43, 44, 45 ], %w[route-20 seafoam-islands cinnabar-island].map { |s| loc(s).order },
      "the islands take their stop number between the route they sit in and the town past them"
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
    assert game.leg!("ss-anne").single?

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
    assert_equal 7, leg1.catch_count
    assert_equal %w[025 016 019], g.new_dex_for_leg(leg1)
    assert_equal 3, g.obtainable_upto_leg(leg1).size
    assert_equal 104, g.obtainable_dex.size,
      "the two the Fighting Dojo hands over are obtainable; a save only ever registers one, the " \
      "Surf sweep adds the Psyduck line, which no earlier pass could reach, and the Power Plant " \
      "hands over an Electrode, which spawns in no table anywhere"
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
    assert_equal %w[pewter-city cerulean-city vermilion-city-return celadon-city-return fuchsia-city-return saffron-city-return cinnabar-island viridian-gym],
      game.locations.select(&:badge?).map(&:slug)
    assert_equal %w[cinnabar-island], game.leg!("leg-15").gyms.map(&:slug)
    assert_equal %w[viridian-gym], game.leg!("leg-16").gyms.map(&:slug)
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

  # The park is the one stop the guide cannot finish in one go: its clock turns you out, and the
  # Nugget out on the Center Area's island needs a Surf that Koga's badge unlocks two stops later.
  # So the page runs one numbered sequence across two headings rather than filing the leftovers as
  # a footnote, and the return trip carries the three things the first trip could not take.
  test "the Safari Zone splits its steps across the visit that has Surf and the one that does not" do
    park = loc("safari-zone")

    assert park.second_visit?
    assert_equal (1..13).to_a, park.lead_steps.map(&:n)
    assert_equal [ 14, 15, 16, 17 ], park.second_visit_steps.map(&:n)
    assert_equal [ "Nugget", "Max Revive", "Max Potion" ],
      park.second_visit_steps.flat_map { |step| step.items.map(&:name) }
    assert_empty park.later, "the return trip is steps now, not a come-back-later block"
    assert_equal "HM03 Surf", park.lead_steps.last(2).first.items.sole.name,
      "the first visit ends on the HM, then the step that spends the rest of the clock"
  end

  test "a stop with no second visit keeps every step in one block" do
    plain = loc("rocket-hideout")

    refute plain.second_visit?
    assert_equal plain.steps, plain.lead_steps
    assert_empty plain.second_visit_steps
  end

  test "a finale gym only sits on a multi-stop leg, where the leg page can render it" do
    assert_empty game.legs.select { |leg| leg.single? && leg.locations.any?(&:gym_finale?) }
  end

  # The Safari Zone stands between the two passes: it is a page of its own, so Koga cannot close
  # the leg he used to close. The badge moves onto the second pass with the Warden's trade, the
  # way Erika's does after the Rocket Hideout.
  test "Fuchsia is walked twice, with Koga on the pass that follows the Safari Zone" do
    first, back = loc("fuchsia-city"), loc("fuchsia-city-return")

    assert_nil first.gym, "the gym belongs to the second pass"
    assert_nil first.badge
    assert_equal %w[fuchsia-city], game.leg!("leg-11").locations.map(&:slug).last(1)
    assert_equal %w[safari-zone], game.leg!("safari-zone").locations.map(&:slug)
    assert_equal %w[fuchsia-city-return], game.leg!("leg-12").locations.map(&:slug).first(1)
    assert back.band_gym?, "a one-stop leg renders its gym in the band, not as a finale"
    assert_equal [ 1 ], back.lead_steps.map(&:n)
    assert_equal [ 2, 3 ], back.after_steps.map(&:n),
      "after the badge: teach Surf and go back for the park, then west for Cycling Road"
    assert_equal "HM04 Strength", back.steps.first.items.sole.name
  end

  # Saffron's gym is Rocket-held until Silph is cleared, so the city is arrived at, left, and come
  # back to, the way Fuchsia is around the Safari Zone. The badge travels with the second pass,
  # which is what puts the Marsh deadline on the page before the gym rather than the page after it.
  test "Saffron is walked twice, with Sabrina on the pass that follows Silph Co." do
    first, back = loc("saffron-city"), loc("saffron-city-return")

    assert_nil first.gym, "the gym belongs to the second pass"
    assert_nil first.badge
    assert_equal 41, first.order
    assert_equal 41, back.order, "same stop, walked twice"
    assert_equal "MARSH", back.badge
    assert_equal %w[saffron-city], game.leg!("leg-12").locations.map(&:slug).last(1)
    assert_equal %w[silph-co], game.leg!("silph-co").locations.map(&:slug)
    assert_equal %w[saffron-city-return surf-cleanups], game.leg!("leg-13").locations.map(&:slug)
    assert_operator game.legs.index(game.leg!("silph-co")), :<, game.legs.index(game.leg!("leg-13"))
  end

  # The dojo is a gym in all but the badge, so it lands on the first pass with its own five fights
  # and the prize the Karate Master hands over in place of one.
  test "the Fighting Dojo carries its own room, and the second Saffron pass carries none of it" do
    dojo = loc("saffron-city").dojo

    assert_equal Walkthrough::Yellow::DOJO_MAP, dojo.map
    assert_equal 4, dojo.trainers.size
    assert_equal "BLACKBELT:1", dojo.leader.opp
    assert_equal 4_175, dojo.purse
    assert(dojo.trainers.all? { |card| card.where.map? })
    assert_nil loc("saffron-city-return").dojo
    assert_empty loc("saffron-city-return").trainers,
      "the dojo's five come off Saffron's one roster; only the pass that owns the dojo shows them"
  end

  # The dojo's floor is drawn and pinned like a gym's, so it leaves the stop's header maps and the
  # cards read their letters off it. The pass that borrows Saffron's maps but owns no dojo drops it.
  test "the dojo's floor is a map of its own, not one of the city's" do
    dojo = loc("saffron-city").dojo

    assert_equal "saffron-city-dojo", dojo.area.name
    assert_equal "Dojo", dojo.area.floor
    assert_equal dojo.area.image, dojo.shot.image
    assert_equal %w[T1 T2 T3 T4 T5], dojo.pins.map(&:key)
    assert_equal "T5", dojo.leader.marker_key, "the walk ends on the one at the back"
    assert_equal %w[saffron-city], loc("saffron-city").area_maps.map(&:name)
    assert_equal %w[saffron-city], loc("saffron-city-return").area_maps.map(&:name)
  end

  # You leave with one of the pair and the other ball stays shut, so the choice is drawn from the
  # game's own numbers: the bar lights up on the stat each one actually wins, and Special ties.
  test "the dojo choice compares the two the Karate Master leaves behind" do
    lee, chan = loc("saffron-city").dojo.choice.picks

    assert_equal [ "left", "106", 30 ], [ lee.side, lee.dex, lee.level ]
    assert_equal [ "right", "107", 30 ], [ chan.side, chan.dex, chan.level ]
    assert_equal [ "DOUBLE KICK", "MEDITATE" ], lee.knows.map(&:name)
    assert_equal 33, chan.learns.first.level
    assert_equal %w[attack speed], lee.stats.select(&:lead).map(&:key)
    assert_equal %w[defense], chan.stats.select(&:lead).map(&:key)
    assert_equal 100, lee.stats.first.fill, "the best number on either card fills its bar"
  end

  # Both halves are listed the way Cinnabar lists all three fossils: a living dex owes the other
  # even though one cartridge only ever opens one ball.
  test "both dojo Pokemon are obtainable at Saffron and owed by Oak's deadline" do
    saffron = loc("saffron-city")

    assert_equal %w[106 107], saffron.encounters.map(&:dex)
    assert(saffron.encounters.all?(&:gift?))
    assert_equal %w[106 107], saffron.oak_queue.map(&:dex)
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

  test "the Underground Path sits between the routes it joins, carrying only its hidden items" do
    tunnel = loc("underground-path")
    hidden = tunnel.steps.flat_map(&:hidden)

    assert_equal [ 15, 16 ], [ tunnel.order, loc("route-6").order ]
    assert_equal %w[route-5 underground-path route-6 vermilion-city],
      game.leg!("leg-05").locations.map(&:slug)
    assert_empty tunnel.encounters, "nothing is wild down there"
    assert_equal [ [ "Full Restore", "H1" ], [ "X Special", "H2" ] ], hidden.map { |h| [ h.name, h.key ] }
    assert_equal [ { in: "E1" }, { out: "E2" } ], tunnel.steps.map(&:marks),
      "a straight corridor is two steps: in with the first pickup, out with the second"
  end

  test "the forest picks its items up in the order the maze can actually be walked" do
    items = loc("viridian-forest").steps.flat_map(&:items).map { |i| [ i.name, i.at ] }

    assert_equal [ [ "Poké Ball", nil ], [ "Potion", [ 25, 11 ] ], [ "Potion", [ 12, 29 ] ] ], items
  end

  test "starter encounters are gifts while wild encounters are catchable" do
    pallet = loc("pallet-town")
    pikachu = pallet.encounters.find { |enc| enc.how == "STARTER" }
    assert pikachu.gift?
    refute pikachu.wild?
    assert_equal 6, pallet.encounters.size
    assert_equal 5, pallet.catchable_count

    forest = loc("viridian-forest")
    assert forest.encounters.all?(&:wild?)
    assert_equal 4, forest.catchable_count
  end

  test "the best place to catch is a stop you reach already holding the rod or Surf" do
    g = game
    stranded = g.locations.flat_map do |loc|
      loc.encounters.filter_map do |enc|
        next unless g.best_catch_here(loc, enc)
        next if enc.unlocked_from <= loc.order

        "#{enc.name} at #{loc.slug}"
      end
    end

    assert_empty stranded
  end

  # Route 6's water is the only Psyduck in the game and the guide crosses it twenty stops before
  # HM03 exists, so for a long time nothing crowned it: a stop may not claim a catch you cannot
  # make standing on it. The Surf sweep is the stop that finally can, which is what `armed_only`
  # says on the card, and it is the difference between "nowhere" and "here, once you are equipped".
  test "a species locked on every pass is crowned at the stop that comes back armed" do
    g = game
    route6 = loc("route-6")
    psyduck = route6.encounters.find { |enc| enc.dex == "054" }

    assert_equal "SURF", psyduck.how
    assert_operator psyduck.unlocked_from, :>, route6.order, "Route 6 is walked long before Surf"
    assert_nil g.best_catch_here(route6, psyduck), "not on the pass that cannot reach the water"
    assert_equal "surf-cleanups", g.best_catches["054"].slug
    assert g.best_catches["054"].armed_only, "the only stop you arrive at already equipped"
    assert_equal "surf-cleanups", g.best_catches["055"].slug
  end

  # The guard behind all of the above: a species whose every stop is one you reach without the tool
  # for it is crowned nowhere at all. No species is in that position any more, now the Surf sweep
  # goes back for the last of them, so it is exercised on the one stop rather than on the game:
  # Route 6 alone, walked twenty stops before HM03, can crown nothing.
  test "a species nobody is armed for at any stop is crowned nowhere" do
    route6 = loc("route-6")
    psyduck = route6.encounters.find { |enc| enc.dex == "054" }

    assert_nil Walkthrough::Yellow.best_catch("054", [ { loc: route6, enc: psyduck, pct: 94 } ])
  end

  test "a species is not crowned at a stop whose rod arrives many stops later" do
    g = game
    route22 = loc("route-22")
    magikarp = route22.encounters.find { |enc| enc.dex == "129" }

    assert_equal "OLD ROD", magikarp.how
    assert_operator magikarp.unlocked_from, :>, route22.order, "Route 22 is before the Old Rod"
    assert_nil g.best_catch_here(route22, magikarp)
    refute_equal "route-22", g.best_catches["129"].slug
  end

  test "a species catchable at one armed stop says so, without claiming to be the only one" do
    best = game.best_catches["119"]

    assert_equal "cerulean-cave", best.slug
    assert best.armed_only
    refute best.only, "Seaking also lives on Route 4 and Route 24, just behind a later rod"
  end

  test "gating the ranking on the tools you carry costs only the two it must" do
    assert_equal 94, game.best_catches.size
  end

  test "a stop boxes its catchables by method, in section order rather than authoring order" do
    sections = loc("route-24").encounter_sections

    assert_equal [ "GIFT", "GRASS", "OLD ROD", "GOOD ROD", "SUPER ROD" ], sections.map(&:code),
      "the Charmander is authored last and must still come out first"
    assert_equal [ 1, 5, 1, 2, 2 ], sections.map(&:size)
  end

  test "a starter files under the gift box while its card keeps the STARTER tag" do
    sections = loc("pallet-town").encounter_sections

    assert_equal [ "GIFT", "OLD ROD", "GOOD ROD", "SUPER ROD" ], sections.map(&:code)
    assert sections.first.gift?
    assert_equal "STARTER", sections.first.encounters.sole.how
  end

  test "a method the stop has no Pokemon for gets no box at all" do
    assert_equal [ "GRASS" ], loc("route-3").encounter_sections.map(&:code)
  end

  test "a box names the sprite and the copy keys it renders with" do
    section = loc("safari-zone").encounter_sections.first

    assert_equal "safari", section.key
    refute section.gift?
    assert_equal "walkthrough/items/safari-ball.png", section.icon
    assert_equal "walkthrough.ui.catchsec_safari_label", section.label_key
    assert_equal "walkthrough.ui.catchsec_safari_hint", section.hint_key
  end

  test "a species on one floor of a multi-floor cave still says which floor" do
    sandshrew = loc("mt-moon").encounters.find { |enc| enc.dex == "027" }

    assert_equal 1, sandshrew.places.size
    assert_equal "1F", sandshrew.places.sole.floor
    assert sandshrew.places?, "Mt. Moon has three floors, so 1F-only is the fact worth printing"
  end

  test "a route species with one unfloored table breaks out nothing" do
    refute loc("route-3").encounters.find { |enc| enc.dex == "027" }.places?
  end

  test "tall grass is titled by the game's own grass tile, not by a stand-in item" do
    section = loc("route-1").encounter_sections.find { |s| s.code == "GRASS" }

    assert_equal "walkthrough/yellow/icons/tall-grass.png", section.icon
  end

  test "a multi-word method slugs into one key for the id, the class and the copy" do
    section = loc("rocket-hideout").encounter_sections.find { |s| s.code == "GAME CORNER" }

    assert_equal "game-corner", section.key
    assert_equal "walkthrough.ui.catchsec_game_corner_label", section.label_key
  end

  test "a method with no box raises rather than dropping its cards" do
    error = assert_raises(Walkthrough::UnknownEncounterSection) do
      stub_location("route-99", [ encounter_by("MIRAGE") ]).encounter_sections
    end

    assert_match "route-99", error.message
    assert_match "MIRAGE", error.message
  end

  test "a box counts its cards but tallies its species" do
    section = stub_location("route-99", [ encounter_by("GRASS"), encounter_by("GRASS") ])
      .encounter_sections.sole

    assert_equal 2, section.size
    assert_equal [ "016" ], section.dex_list
  end

  test "every catchable in the game lands in exactly one box, and every box is used" do
    codes = game.locations.flat_map do |l|
      assert_equal l.encounters.size, l.encounter_sections.sum(&:size), "#{l.slug} lost a card"
      l.encounter_sections.map(&:code)
    end

    assert_equal Walkthrough::SECTION_ICONS.keys.sort, codes.uniq.sort
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

  # Rock Tunnel numbers its pins per map, so two trainers wear T6 on one page. The floor is what
  # tells them apart, and it comes off the roster rather than being read back out of a pin id.
  test "a trainer carries the floor the roster puts it on" do
    tunnel = loc("rock-tunnel")
    upper, lower = tunnel.trainers.partition { |t| t.floor == "1F" }

    assert_equal 7, upper.size
    assert_equal [ "B1F" ], lower.map(&:floor).uniq
    assert_equal %w[T1 T2 T3 T4 T5 T6 T7], (upper.map(&:marker_key) & lower.map(&:marker_key)).sort,
      "the pin letters collide across floors, which is the whole reason for the badge"
  end

  test "a one-floor stop leaves the floor blank, and so does a gym" do
    assert_empty loc("route-3").trainers.filter_map(&:floor), "a route is all one floor"
    assert_equal [ "Gym" ], loc("celadon-city-return").gym.trainers.map(&:floor).uniq,
      "every trainer in a gym reads the same, so no card can single one out"
  end

  test "a boss met in a scripted scene has no floor to name" do
    rival = loc("silph-co").trainers.find { |t| t.name == "Blue" }

    assert_nil rival.floor, "the generated roster has no entry for a scripted fight"
  end

  # A stop that walks well past its own map is titled for the whole walk, but the place it is
  # anchored to keeps its own name, so the map titlebar, the catch cards and the planner's "do at"
  # badge still say where Diglett actually lives.
  test "a stop titled for its whole walk keeps the plain place name underneath" do
    detour = loc("digletts-cave")

    assert_equal "Diglett's Cave", detour.name
    assert_equal "Diglett's Cave → Viridian Detour", detour.title
    assert_equal "Diglett's Cave", detour.area_maps.first.title || detour.name
    assert_equal detour.title, game.leg!("digletts-cave").from, "the index card and nav read the title"
  end

  # The detour walks four maps and draws them one at a time, so what lives on a map has to hang
  # off it rather than pile up at the foot of a page that ends three maps later.
  test "what lives on a borrowed map is pinned to that map" do
    detour = loc("digletts-cave")
    drawn = detour.step_groups.filter_map(&:first).map(&:name)

    assert_equal %w[digletts-cave route-2 viridian-city pewter-city], drawn
    assert_equal %w[050 051], detour.encounters_on("digletts-cave").map(&:dex)
    assert_empty detour.encounters_on("route-2"), "no Diglett lives up on the route"
    assert_equal "Mr. Mime", detour.trades_on("route-2").sole.receive[:name]
    assert_empty detour.encounters_off(drawn)
    assert_empty detour.trades_off(drawn), "every card on this page has a map to sit under"
  end

  test "a stop that draws its maps together keeps its catches below the steps" do
    forest = loc("viridian-forest")

    assert_empty forest.step_groups, "the forest is one map, so its steps never name one"
    assert_equal forest.encounters, forest.encounters_off([]),
      "with no map drawn on its own, every card stays loose"
  end

  test "a stop with nothing to add to its name is titled by it" do
    plain = loc("route-11")

    assert_equal "Route 11", plain.name
    assert_equal plain.name, plain.title
    assert_equal "Route 11", game.leg!("leg-06").from
  end

  test "the seven usable in-game trades sit at their real locations" do
    cards = game.locations.flat_map(&:trades)
    assert_equal 7, cards.uniq(&:title_key).size, "Yellow has 7 usable NPC trades"
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
    trades = game.locations.flat_map(&:trades).uniq(&:title_key)
    dexes = trades.flat_map { |t| [ t.give[:dex], t.receive[:dex] ] }
    assert_equal 14, dexes.size
    dexes.each { |dex| assert_match(/\A\d{3}\z/, dex) }
  end

  # A trade the guide flags long before you can make it (Route 2 tells you to keep a Mt. Moon
  # Clefairy) shows again on the stop that finally walks there. Two cards, one trade: the second
  # carries the first's tick id so trading once reads as traded on both pages.
  test "a trade flagged early and walked to later is one tick shown twice" do
    flagged = loc("route-2").trades.sole
    walked = loc("digletts-cave").trades.sole

    assert_nil flagged.tick, "the stop that owns the trade keeps its positional id"
    assert_equal "route-2/trade-0", walked.tick
    assert_equal flagged.title_key, walked.title_key
    assert_equal "MILES", walked.nick
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

    surge = loc("vermilion-city-return").gym
    assert surge.puzzle?
    assert_equal 3, surge.puzzle.size
    assert surge.puzzle[1].shot?
    refute surge.puzzle[0].shot?
  end

  test "a gym leader card ticks the very pin that stands for her on the map" do
    gyms = game.locations.select(&:gym?)
    assert_equal 8, gyms.size

    gyms.each do |loc|
      maps = loc.area_maps + [ loc.gym.area ].compact
      pins = maps.flat_map { |map| map.markers_in("trainer").map { |pin| "#{map.name}/#{pin.id}" } }
      assert_includes pins, loc.gym.leader.tick,
        "#{loc.gym.name}: the leader card would tick a key no pin on the map writes"
    end
  end

  test "the badge guide explains all eight badges and the four rules behind them" do
    guide = Walkthrough::Yellow.badge_guide
    assert_equal "badges-explained", guide.anchor
    assert_equal (1..8).to_a, guide.cards.map(&:no)
    assert_equal %w[Boulder Cascade Thunder Rainbow Soul Marsh Volcano Earth], guide.cards.map(&:name)

    boulder = guide.cards.first
    refute boulder.obey?
    assert_nil boulder.level
    assert_equal "walkthrough.yellow.badge_guide.boost.attack", boulder.effect_key
    assert_equal "Flash", boulder.field

    cascade = guide.cards.second
    assert cascade.obey?
    assert_equal 30, cascade.level
    assert_equal "walkthrough.yellow.badge_guide.obey", cascade.effect_key

    assert_equal %w[Marsh Volcano Earth], guide.cards.reject(&:field?).map(&:name)
    assert_equal [ 1, 2, 3, 4 ], guide.rules.map(&:no)
    assert_equal "walkthrough.yellow.badge_guide.rules.stacking.title", guide.rules.second.title_key
  end

  test "the badge guide's badges, leaders and crests stay in step with the gyms" do
    gyms = game.locations.select(&:gym?).map(&:gym)
    cards = Walkthrough::Yellow.badge_guide.cards

    assert_equal gyms.map(&:badge), cards.map { |card| card.name.upcase }
    assert_equal gyms.map { |gym| gym.leader.name }, cards.map(&:leader)
    assert_equal gyms.map(&:badge_img), cards.map(&:image)
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
    assert_equal "Route 21", pidgey.alt_name
    assert_equal "55%", pidgey.alt_rate

    nidoran = bc.fetch("029")
    assert_equal "route-22", nidoran.slug
    assert nidoran.tie, "Nidoran♀'s 30% is matched elsewhere, so the earliest location wins"

    refute bc.key?("025"), "Pikachu is a gift, not a rated wild catch"
    refute pidgey.only, "Pidgey turns up in more than one place, so it is a ranked win"
  end

  test "best_catches tags a species with a single location as the only place to catch it" do
    bc = game.best_catches

    clefairy = bc.fetch("035")
    assert clefairy.only, "Clefairy lives in Mt. Moon and nowhere else"
    assert_equal "mt-moon", clefairy.slug
    assert_equal "11%", clefairy.rate
    assert_nil clefairy.alt_name, "there is no rival spot to compare against"

    zapdos = bc.fetch("145")
    assert zapdos.only, "Zapdos is a lone static"
    assert_equal "power-plant", zapdos.slug
    assert_nil zapdos.rate, "a static has no encounter percentage to quote"
    refute zapdos.rate?
  end

  test "best_catches skips a species whose spots cannot be ranked or called the only one" do
    bc = game.best_catches

    refute bc.fetch("037").rate?, "Vulpix is bought with Game Corner coins, which do not rank against a rate"
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
    end.reject { |_label, node| node.nil? } +
      Walkthrough::Yellow.surf_pikachu.shots.map { |s| [ "surfing pikachu #{s.key}", s ] }
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
    roots = [ game, Walkthrough::Yellow.mew_glitch, Walkthrough::Yellow.surf_pikachu ]
    referenced = roots.flat_map { |r| every_referenced_image(r) }
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

  test "every letter a step names is worn by a pin on that location's map" do
    missing = I18n.available_locales.flat_map do |locale|
      I18n.with_locale(locale) do
        game.locations.flat_map do |loc|
          keys = loc.area_maps.flat_map { |m| m.markers.map(&:key) }.compact
          loc.steps.flat_map { |s| I18n.t(s.text_key).scan(/pn-wt-mark">([A-Z])</).flatten }
            .uniq.reject { |k| keys.include?(k) }.map { |k| "#{locale} #{loc.slug} names #{k}" }
        end
      end
    end

    assert_empty missing, "prose names a letter but no pin on that map wears it"
  end

  test "every pin a step names is a real marker on that location's own maps" do
    stray = game.locations.flat_map do |loc|
      ids = loc.area_maps.flat_map { |m| m.markers.map { |k| "#{m.name}/#{k.id}" } }.to_set
      loc.steps.flat_map { |s| s.pins.values }.uniq.reject { |id| ids.include?(id) }
        .map { |id| "#{loc.slug} names #{id}" }
    end

    assert_empty stray, "a mistyped pin id would print nothing where a key belongs"
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

    assert_equal 23, loose.size
    assert_equal [ "Bicycle", "Bike Voucher", "Coin Case", "Exp. All", "Fossil", "Good Rod",
                   "HM01 Cut", "HM02 Fly", "HM03 Surf", "HM04 Strength", "Master Ball",
                   "Oak's Parcel", "Old Amber", "Old Rod", "Poké Flute", "Pokédex", "Potion",
                   "S.S. Ticket", "Super Rod", "TM36 Selfdestruct", "TM39 Swift",
                   "Town Map" ], loose.map(&:name).uniq.sort,
      "the Itemfinder left this set the moment a second page claimed it: two cards for one gift " \
      "need a stable id between them, not a slot number on each page"
    assert(loose.none? { |item| game.locations.any? { |l| l.later.any? { |x| x.name == item.name } } },
      "a gift another stop also lists is keyed to that stop (gift_tick), never positionally")
  end

  test "a step that names a staircase renders the key the map wears on both its floors" do
    steps = loc("mt-moon").steps

    assert_equal "text_html", steps[2].text_key.split(".").last,
      "the keys are markup, so the step reads from an _html key"
    assert_equal({ down: "E4", lower: "E7" }, steps[2].marks)
    refute_equal "text_html", steps[0].text_key.split(".").last,
      "a step with no pin to point at stays plain text"
  end

  test "both ends of a staircase wear one key, so the two floors read as connected" do
    floors = loc("mt-moon").area_maps.to_h do |m|
      [ m.floor, m.markers.select { |k| k.cat == "exit" }.to_h { |k| [ k.id, k.key ] } ]
    end

    assert_equal "E2", floors["1F"]["exit-5-5"]
    assert_equal "E2", floors["B1F"]["exit-5-5"], "the far side of the same staircase"
    assert_equal "E4", floors["1F"]["exit-25-15"]
    assert_equal "E4", floors["B1F"]["exit-25-15"]
    assert_equal "E7", floors["B1F"]["exit-13-27"]
    assert_equal "E7", floors["B2F"]["exit-15-27"], "it lands well away from where it started"
  end

  test "a doorway out of the location is nobody's twin, so it keeps a key of its own" do
    outside = loc("mt-moon").area_maps.first.markers.find { |k| k.id == "exit-14-35" }
    twins = loc("mt-moon").area_maps.flat_map { |m| m.markers.select { |k| k.cat == "exit" } }

    assert_equal "E1", outside.key, "Route 3 draws its far side, not Mt. Moon"
    assert_equal "▼", outside.glyph_or_key, "the pin still says which way it goes"
    assert_equal 1, twins.count { |k| k.key == "E1" }
  end

  test "an exit on a single-floor map is keyed like any other" do
    forest = loc("viridian-forest").area_maps.first.markers.select { |k| k.cat == "exit" }

    assert_equal %w[E1 E2], forest.map(&:key)
  end

  test "locations carry plain rendered area maps" do
    g = game
    vf = loc("viridian-forest")
    assert_equal 1, vf.area_maps.size
    assert_equal "walkthrough/yellow/maps/viridian-forest.png", vf.area_maps.first.image
    refute_predicate vf.area_maps.first, :captioned?

    floors = loc("mt-moon").area_maps
    assert_equal %w[1F B1F B2F], floors.map(&:floor)
    assert_equal "1F", floors.first.caption
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

  def encounter_by(how)
    Walkthrough::Encounter.new(dex: "016", name: "Pidgey", how: how, rate: "50%", level: "3",
      rarity: "COMMON", tip_key: nil, evo_line: [], at_map: "route-1")
  end

  def stub_location(slug, encounters)
    Walkthrough::Location.new(slug: slug, kind: "ROUTE", name: slug.titleize, order: 99,
      note_key: "n", intro_key: "i", badge: nil, steps: [], encounters: encounters,
      trainers: [], oak_queue: [])
  end

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
