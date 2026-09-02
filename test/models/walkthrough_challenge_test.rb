require "test_helper"

class WalkthroughChallengeTest < ActiveSupport::TestCase
  def game = Walkthrough.find!("yellow")

  def challenge = Walkthrough::Challenge

  def plan(slug) = game.plan_for(game.leg!(slug))

  test "the nine badge windows close on their gyms, in badge order" do
    assert_equal %w[01 02 03 04 05 06 07 08 09], game.windows.map(&:label)
    assert_equal [ "Brock", "Misty", "Lt. Surge", "Erika", "Koga", "Sabrina", "Blaine", "Giovanni", nil ],
      game.windows.map(&:leader)
    assert_equal %w[pewter-city cerulean-city vermilion-city-return celadon-city-return
                    fuchsia-city-return saffron-city-return cinnabar-island-return viridian-gym
                    cerulean-cave],
      game.windows.map { |win| win.slugs.last }
    assert game.windows.last.final?, "nothing closes the run but the League"
    assert_equal "Pewter Gym", game.windows.first.gym_name
    assert_nil game.windows.last.gym_name
  end

  test "every leg sits in exactly one window, taken from where the page ends" do
    assigned = game.legs.to_h { |leg| [ leg.slug, plan(leg.slug).window.number ] }

    assert_equal 34, assigned.size
    assert_equal [ 1, 1, 1, 1, 2, 2, 2, 3, 4, 4, 4, 4, 4, 4, 5, 5, 5, 6, 6, 7, 7, 7, 7, 8, 8, 9, 9, 9, 9 ].uniq,
      assigned.values.uniq
    assert_equal 1, assigned.fetch("viridian-forest"), "the forest is still before Brock"
    assert_equal 2, assigned.fetch("leg-03"), "Brock closes mid-page, so the page looks ahead to Misty"
  end

  test "a stage that only ever stands in a ball fills its own box slot" do
    voltorb = challenge.later_for(game, "100")

    assert_equal :static, voltorb.kind, "Electrode is caught at the plant, not grown from a spare"
    assert_equal "Power Plant", voltorb.args[:stop]
    assert challenge.self_sourced?(game, "101"),
      "two of the disguised balls are an Electrode, and a ball that waits is a certain body"
    assert_equal 1, challenge.bodies_for(game, "100"),
      "so the line stops asking for a spare Voltorb to walk up to Lv 30"
  end

  test "the Safari Zone and Silph Co. land in the window their gym closes" do
    assert game.windows[4].covers?("safari-zone"), "the Safari Zone is inside the Koga window"
    assert_equal "Koga", plan("leg-11").window.leader
    assert game.windows[5].covers?("silph-co"), "Silph Co. is inside the Sabrina window"
    assert_equal "Sabrina", plan("silph-co").window.leader
  end

  test "the roster reachable before Brock is exactly the index's hand-written Oak example" do
    assert_equal Walkthrough::Yellow::OAK_EXAMPLE.map(&:first).sort,
      challenge.registerable(game, "pewter-city").sort
  end

  test "a stone evolution joins the roster only once its stone is reachable" do
    before_moon = challenge.registerable(game, "route-3")
    after_moon = challenge.registerable(game, "mt-moon")

    refute_includes before_moon, "031"
    assert_includes after_moon, "031", "Mt. Moon hands over the Moon Stone"
    assert_includes after_moon, "034"
    refute_includes challenge.registerable(game, "route-9"), "045", "the Leaf Stone waits for Celadon"
    assert_includes challenge.registerable(game, "celadon-city"), "045"
  end

  test "a trade evolution never joins the roster, because one cartridge cannot do it" do
    endgame = challenge.registerable(game, "cerulean-cave")

    %w[065 068 076 094].each { |dex| refute_includes endgame, dex }
    assert_includes endgame, "064", "Kadabra still counts, only Alakazam is out of reach"
  end

  test "bodies are counted so every stage of a family ends up in its own box" do
    assert_equal 1, challenge.bodies_for(game, "010"),
      "Metapod is 25% of the same forest, so one Caterpie is all the forest owes"
    assert_equal 2, challenge.bodies_for(game, "011"),
      "one Metapod stays, one takes the ten levels to the Butterfree nothing spawns"
    assert_equal 1, challenge.bodies_for(game, "001"), "the only Bulbasaur in the game is a single gift"
  end

  # The whole point of the 4% line: a stage you can walk up to is a stage you catch. Pidgeot used
  # to cost a third Pidgey walked 36 levels; Route 13 hands out Pidgeotto at 15%, so the Pidgey
  # card drops to one and the two stages above it come off the pair of Pidgeotto instead.
  test "a stage that spawns at a reasonable rate is caught there, not evolved up to" do
    assert_equal "017", challenge.body_source(game, "018")
    assert_equal 1, challenge.bodies_for(game, "016")
    assert_equal 2, challenge.bodies_for(game, "017")
    assert_equal "020", challenge.body_source(game, "020"),
      "40% of the Pokémon Mansion beats levelling a second Rattata to 20"
    assert_equal 1, challenge.bodies_for(game, "019")
  end

  # A trade evolution is not something one cartridge can perform, so Oak will never register it,
  # but a box still holds one: you hand the Kadabra over and your partner hands it back. What that
  # costs is a second Kadabra, and counted as unreachable the four of them fell off the plan
  # entirely rather than asking for it.
  test "a stage behind a trade still costs a spare body of the stage below" do
    { "064" => "065", "067" => "068", "075" => "076", "093" => "094" }.each do |below, traded|
      assert_equal below, challenge.body_source(game, traded),
        "#{Walkthrough::Yellow::NAMES.fetch(traded)} comes off a spare #{Walkthrough::Yellow::NAMES.fetch(below)}"
      assert_equal 2, challenge.bodies_for(game, below),
        "one stays put, one goes out to be traded back"
    end
  end

  # The prize counter carries a price where a wild card carries a percentage, which reads as no
  # odds at all. Left at that the only Vulpix in the game could source nothing, and Ninetales,
  # whose one route into a box is a Fire Stone on a spare Vulpix, went missing from the plan.
  test "a prize counter sources bodies the way a common spawn does" do
    assert challenge.purchasable?(game, "037"), "Vulpix is bought at the Game Corner"
    refute challenge.purchasable?(game, "016"), "a Pidgey is not for sale anywhere"
    assert_nil challenge.top_rate(game, "037"), "a coin price is not a rate"
    assert_equal "037", challenge.body_source(game, "038")
    assert_equal 2, challenge.bodies_for(game, "037")
  end

  test "a stage under the line is grown from the best-odds ancestor, never hunted" do
    assert_equal 1, challenge.top_rate(game, "085"), "Dodrio is 1% of Route 17 and nowhere better"
    assert_equal "084", challenge.body_source(game, "085")
    assert_equal 2, challenge.bodies_for(game, "084"), "so a second Doduo carries it"
    assert_equal "011", challenge.body_source(game, "012"),
      "Butterfree comes off the nearest rung that clears the line, not the roomiest one"
    assert_equal "010", challenge.body_source(game, "010"), "the root of a line sources itself"
  end

  # Only the stops that hand you the tool count. Slowbro's 6% sat on water the guide crossed long
  # before HM03, so the best odds it could offer were a 1% cave spawn and the queue grew one from
  # a spare Slowpoke instead. The Surf sweep goes back to Route 12 with the HM in the bag, so the
  # 6% is odds you can take at last and Slowbro sources itself.
  test "odds are only odds at a stop that hands you the tool for them" do
    assert_equal 6, challenge.top_rate(game, "080")
    assert_equal "080", challenge.body_source(game, "080"), "caught on its own odds now"
    assert_equal 1, challenge.bodies_for(game, "079"), "so no spare Slowpoke is owed for it"
  end

  # A quota only reads as a decision next to the stage above it, so every species the queue takes
  # carries the one line that explains it: caught on its own odds, grown from a spare body, or
  # stopped dead by a trade.
  test "a queued species says how the stage above it gets filled" do
    kinds = {
      [ "leg-01", "016" ] => :catch, [ "leg-12", "084" ] => :rare,
      [ "viridian-forest", "011" ] => :level, [ "mt-moon", "035" ] => :stone,
      [ "victory-road", "075" ] => :trade, [ "leg-01", "025" ] => :refused
    }
    found = kinds.keys.to_h { |slug, dex| [ [ slug, dex ], plan(slug).entry_for(dex).later ] }

    assert_equal kinds, found.transform_values(&:kind)
    assert_equal({ name: "Pidgeotto", base: "Pidgey", stop: "Route 13", rate: "15%" },
      found[[ "leg-01", "016" ]].args)
    assert_equal "017", found[[ "leg-01", "016" ]].dex, "the note draws the stage it names"
    assert_equal({ name: "Clefable", base: "Clefairy", stone: "Moon Stone" },
      found[[ "mt-moon", "035" ]].args)
  end

  # The card is read where the reader stands, not where the plan files it, so a page that only
  # points at a species still answers the question its evolution line raises: is the stage above
  # catchable too, or does the quota owe a second body? Only a species the run never takes stays
  # silent, because nothing is owed for it anywhere.
  test "a species the page only points at still says how the stage above it gets filled" do
    away = plan("viridian-forest").entry_for("016")

    assert_equal :catch, away.later.kind,
      "Route 1 owns the Pidgey row, but the forest card still says Route 13 has the Pidgeotto"
    assert_equal({ name: "Pidgeotto", base: "Pidgey", stop: "Route 13", rate: "15%" }, away.later.args)
    refute away.fresh?, "and it is still the row Route 1 owns, not a second claim on the body"
    assert_nil plan("leg-12").entry_for("085").later, "nothing is owed for a Dodrio you never catch"
    assert_equal "walkthrough.ui.ld_why_later", plan("leg-01").entry_for("016").why_key,
      "one Pidgey is the whole point, so the row says which stop takes the rest of the line"
  end

  test "a rare ancestor still owes a spare body when the stage above it has no other source" do
    assert_equal "035", challenge.body_source(game, "036"),
      "Clefable only ever comes off a Clefairy, however rare Clefairy is"
    assert_equal 2, challenge.bodies_for(game, "035"),
      "one Clefairy stays, one takes the Moon Stone to become Clefable"
    refute challenge.stage_for(game, "036").owed,
      "Clefable is accounted for now, not left owed with nowhere to come from"
  end

  test "a one-off revival is not a body source, however many stages sit above it" do
    assert_nil challenge.body_source(game, "139"), "the game hands out a single fossil, never a second"
    assert_equal 1, challenge.bodies_for(game, "138")
    assert_equal 1, challenge.bodies_for(game, "140")
  end

  test "a species is queued at its best stop and only there" do
    forest = plan("viridian-forest")

    assert_equal [ "Caterpie", "Metapod" ], forest.queue.map(&:name)
    assert_equal 3, forest.bodies, "one Caterpie, and the pair of Metapod that carries Butterfree"
    assert_equal [ "Pidgey", "Pidgeotto" ], forest.boxed.map(&:name),
      "Route 1 and Route 21 own these, so the forest only points at them"
  end

  test "a page shared by several stops lists each species once, at the stop worth the walk" do
    leg = plan("leg-04")
    oddish = leg.entries.select { |entry| entry.dex == "043" }

    assert_equal 1, oddish.size, "Oddish is on Route 24 and Route 25 but owes one row"
    assert_equal "route-24", oddish.first.at
    assert_equal 1, oddish.first.qty, "Gloom is 10% of Cerulean Cave, so it carries Vileplume too"
    assert_equal 12, leg.entries.size
    assert_equal [ "Bulbasaur", "Mew", "Oddish", "Bellsprout", "Charmander" ], leg.queue.map(&:name),
      "Cerulean is where the glitch puts #151 on the file, so the ledger asks for it here"
  end

  test "a species is grouped by how you would really get it here, not by whether it spawns" do
    catch_here, evolving = plan("leg-04").groups

    assert_includes catch_here.tiles.map(&:name), "Venonat", "10% in the grass is worth the walk"
    assert_includes evolving.tiles.map(&:name), "Venomoth",
      "Venomoth spawns at 1%, so the honest route is levelling the Venonat"
    refute_includes catch_here.tiles.map(&:name), "Venomoth"
  end

  test "a species catchable only past this window is named by its evolution, not its far spawn" do
    forest = plan("viridian-forest")
    fearow = forest.earlier.find { |tile| tile.name == "Fearow" }

    assert_equal "walkthrough.ui.step_level", fearow.via_key,
      "Route 17 is ten legs away, so before Brock the only Fearow is a levelled Spearow"
    assert_equal 20, fearow.via_args[:level]

    spearow = forest.earlier.find { |tile| tile.name == "Spearow" }

    assert_equal "walkthrough.ui.via_catch", spearow.via_key
    assert_equal "GRASS", spearow.via_args[:how]
  end

  test "every Oak list reads in Pokedex order, whatever order the pages hand it over in" do
    page = plan("leg-02")

    [ *page.groups.map(&:tiles), page.earlier, page.locked ].each do |list|
      dexes = list.map(&:dex)

      assert_equal dexes.sort, dexes, "#{dexes.inspect} is out of Pokedex order"
    end
    assert_equal %w[021 029 032 056], page.groups.first.tiles.map(&:dex)
  end

  test "the earlier-stops list is the diff since the last badge, not the whole run" do
    forest = plan("viridian-forest")

    assert_equal 14, forest.earlier.size
    assert_includes forest.earlier.map(&:name), "Pikachu"
    assert_includes forest.earlier.map(&:name), "Pidgeot", "what an earlier catch grows into counts too"

    assert_empty plan("leg-03").earlier,
      "Brock closed on the page before, so the Misty window starts clean here"
  end

  test "an earlier window's registrations never reappear once its badge is taken" do
    misty_page = plan("leg-04")
    before_brock = challenge.registerable(game, "pewter-city")

    assert_empty misty_page.earlier.map(&:dex) & before_brock
    assert_empty misty_page.groups.flat_map(&:tiles).map(&:dex) & before_brock
  end

  test "Oak owes a species once, on the page that first puts it in reach" do
    game.legs.each do |leg|
      opens = challenge.leg_order(leg).first.slug
      already = challenge.registerable_before(game, opens)
      owed = game.plan_for(leg).groups.flat_map(&:tiles).map(&:dex)

      assert_empty owed & already,
        "#{leg.slug} asks again for #{(owed & already).join(', ')}, reachable before the page opens"
    end
  end

  test "a better spot later never re-owes a registration the earliest spot already covered" do
    spearow = "021"

    assert_equal "Route 3", challenge.home_stop(game, spearow).name, "55% beats Route 22's 10%"
    assert_includes plan("leg-02").groups.first.tiles.map(&:dex), spearow
    refute_includes plan("leg-03").groups.flat_map(&:tiles).map(&:dex), spearow
  end

  test "the due count stays global even though the lists reset at each badge" do
    assert_equal 17, plan("viridian-forest").due_count
    assert_operator plan("leg-04").due_count, :>, plan("viridian-forest").due_count
    assert_equal challenge.registerable(game, "cerulean-city").size, plan("leg-04").due_count
  end

  test "locked names what the page unlocks but the window cannot register" do
    forest = plan("viridian-forest")

    assert_equal [ "Raichu", "Nidoqueen", "Nidoking" ], forest.locked.map(&:name)
    assert_equal [ "Raichu", "Alakazam", "Machamp", "Golem", "Gengar" ],
      plan("cerulean-cave").locked.map(&:name),
      "four trade evolutions, plus the Raichu Yellow has no route to at all"
  end

  test "the box ledger walks every stage of each queued family" do
    forest = plan("viridian-forest")
    caterpie = forest.families.first

    assert_equal "Caterpie", caterpie.name
    assert_equal %w[010 011 012], caterpie.stages.map(&:dex)
    assert_equal 3, caterpie.total
    assert_equal 3, forest.stages
    assert_equal 1, forest.families.size,
      "Caterpie and Metapod share a family, so the ledger draws it once"
  end

  # The hideout used to owe nothing at all: it had no species of its own, and Erika closed her
  # window on the page before it. It now carries the Game Corner's two counter-only prizes and
  # sits inside her window, which is the whole reason the walk was reordered.
  test "the Game Corner's prizes are owed on the page that sells them, before Erika" do
    hideout = plan("rocket-hideout")

    assert_equal %w[137 037], hideout.entries.map(&:dex), "Porygon and Vulpix, counter-only"
    assert hideout.entries.all? { |e| e.best.only }, "neither turns up anywhere else in Yellow"
    assert_equal "Erika", hideout.window.leader, "and her badge is still ahead of the page"
  end

  test "the ship owes Oak nothing to catch, but still sits inside Surge's window" do
    ship = plan("ss-anne")

    refute ship.living?, "the S.S. Anne has no species of its own"
    assert ship.oak?, "Surge is now on the far side of the ship, so his deadline is still open"
    assert_equal "Lt. Surge", ship.window.leader
  end

  # The League owes no catch of its own and still carries a reminder: Moltres is the one bird the
  # road up never passes, so it stands overdue on the last page before the Elite Four.
  test "a page can owe an Oak reminder without owing a single catch" do
    league = plan("indigo-plateau")

    refute league.living?
    assert league.oak?
    assert_equal %w[146], league.earlier.map(&:dex)
  end

  # Cinnabar is walked either side of the Pokémon Mansion, since the gym's door needs the Secret
  # Key from inside it, and the Mansion is a page of its own like every other dungeon. All three
  # sit inside Blaine's window rather than after it, so each owes what it holds: the lab takes the
  # fossils, the Mansion is where Growlithe and Ditto live, and nothing is carried over to Viridian.
  test "the fossils and the Mansion's own catches fall due by the badge they precede" do
    lab, mansion, viridian = %w[leg-15 pokemon-mansion leg-17].map { |slug| plan(slug) }

    assert_equal 7, lab.window.number, "Blaine's window, not Giovanni's"
    assert_equal %w[138 140 142], lab.groups.find { |g| g.kind == :catch }.tiles.map(&:dex)
    assert_equal %w[058 132], mansion.groups.find { |g| g.kind == :catch }.tiles.map(&:dex)
    assert_equal %w[059], mansion.groups.find { |g| g.kind == :evolve }.tiles.map(&:dex)
    refute viridian.any?, "and nothing is left owing on the page after the badge"
  end

  # Officer Jenny checks wBeatGymFlags for the Thunder Badge before handing the Squirtle over, so
  # the line cannot possibly stand registered before the gym that unlocks it. Its deadline is the
  # next badge, even though the stop that gives it closes Surge's window.
  test "a gift a gym unlocks falls due at the next badge, not that gym's" do
    surge = plan("leg-06")
    next_window = plan("digletts-cave")

    assert_equal "Lt. Surge", surge.window.leader
    assert_empty %w[007 008 009] & surge.due, "the Thunder Badge is won on this very page"
    assert_equal "Erika", next_window.window.leader
    assert_empty %w[007 008 009] - next_window.due,
      "Wartortle and Blastoise follow Squirtle out of Surge's window"
  end

  # The rest of the run takes a species on the page that owes it, so a tile only says how. This
  # one sits a leg behind the deadline it counts toward, so it has to say where too.
  test "an owed species you take on an earlier page names the stop it waits at" do
    tiles = plan("digletts-cave").groups.flat_map(&:tiles).to_h { |tile| [ tile.name, tile ] }

    assert_equal "walkthrough.ui.via_away", tiles.fetch("Squirtle").via_key
    assert_equal({ how: "GIFT", stop: "Vermilion City" }, tiles.fetch("Squirtle").via_args)
    assert_equal "walkthrough.ui.via_catch", tiles.fetch("Diglett").via_key,
      "a species you take on this page still just says how"
  end

  test "every leg builds a plan whose queue never outruns the species on the page" do
    game.legs.each do |leg|
      page = game.plan_for(leg)

      assert_operator page.queue.size, :<=, page.entries.size, leg.slug
      assert_equal page.entries.map(&:dex).uniq, page.entries.map(&:dex), "#{leg.slug} repeats a species"
      assert page.window, "#{leg.slug} sits outside every window"
    end
  end

  # One Eevee is one evolution. Listing Vaporeon, Jolteon and Flareon as three things to register
  # asks a single-cartridge run for two trades it never said it wanted.
  test "the Eevee stones are one pick, not three registrations" do
    groups = plan("leg-09").groups.select(&:any?).to_h { |g| [ g.kind, g ] }

    assert_equal %w[Vileplume Victreebel], groups[:evolve].tiles.map(&:name),
      "the Gloom and Weepinbell lines stay, because both bases are catchable over and over"
    assert_nil groups[:evolve].pick, "so that group wants all of them"

    choice = groups.fetch(:choice)
    assert_equal %w[Vaporeon Jolteon Flareon], choice.tiles.map(&:name)
    assert_equal 1, choice.pick, "whichever stone you use is the one that registers"
  end

  # Both halves of the rule matter, and so does the page it is asked on.
  test "a line is a pick only when its base is uncatchable and its siblings are on the page" do
    assert challenge.one_specimen_line?(game, "134", %w[134 135 136]),
      "Vaporeon shares an uncatchable Eevee with two siblings"
    refute challenge.one_specimen_line?(game, "134", %w[134]),
      "on a page showing one stone there is nothing to choose between"
    refute challenge.one_specimen_line?(game, "045", %w[045 071]),
      "Vileplume's Gloom is catchable over and over, so it is not a choice"
    refute challenge.one_specimen_line?(game, "133", %w[133]),
      "nothing evolves into Eevee, so it has no base to share"
    refute challenge.one_specimen_line?(game, "134", %w[134 133]),
      "Eevee itself is on the page as a catch, not as a sibling stone"
  end
end
