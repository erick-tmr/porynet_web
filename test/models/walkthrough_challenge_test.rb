require "test_helper"

class WalkthroughChallengeTest < ActiveSupport::TestCase
  def game = Walkthrough.find!("yellow")

  def challenge = Walkthrough::Challenge

  def plan(slug) = game.plan_for(game.leg!(slug))

  test "the nine badge windows close on their gyms, in badge order" do
    assert_equal %w[01 02 03 04 05 06 07 08 09], game.windows.map(&:label)
    assert_equal [ "Brock", "Misty", "Lt. Surge", "Erika", "Koga", "Sabrina", "Blaine", "Giovanni", nil ],
      game.windows.map(&:leader)
    assert_equal %w[pewter-city cerulean-city vermilion-city celadon-city fuchsia-city
                    saffron-city cinnabar-island viridian-gym cerulean-cave],
      game.windows.map { |win| win.slugs.last }
    assert game.windows.last.final?, "nothing closes the run but the League"
    assert_equal "Pewter Gym", game.windows.first.gym_name
    assert_nil game.windows.last.gym_name
  end

  test "every leg sits in exactly one window, taken from where the page ends" do
    assigned = game.legs.to_h { |leg| [ leg.slug, plan(leg.slug).window.number ] }

    assert_equal 27, assigned.size
    assert_equal [ 1, 1, 1, 1, 2, 2, 2, 3, 4, 4, 4, 4, 4, 4, 5, 5, 5, 6, 6, 7, 7, 7, 7, 8, 8, 9, 9, 9, 9 ].uniq,
      assigned.values.uniq
    assert_equal 1, assigned.fetch("viridian-forest"), "the forest is still before Brock"
    assert_equal 2, assigned.fetch("leg-03"), "Brock closes mid-page, so the page looks ahead to Misty"
  end

  test "the Safari Zone and Silph Co. land in the window their gym closes" do
    assert game.windows[4].covers?("safari-zone"), "the Safari Zone is inside the Koga window"
    assert_equal "Koga", plan("leg-09").window.leader
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
    assert_equal 2, challenge.bodies_for(game, "010"), "one Caterpie stays, one becomes Butterfree"
    assert_equal 1, challenge.bodies_for(game, "011"), "a wild Metapod fills its own slot"
    assert_equal 2, challenge.bodies_for(game, "016"), "Pidgeotto is catchable, so Pidgey only owes Pidgeot"
    assert_equal 1, challenge.bodies_for(game, "001"), "the only Bulbasaur in the game is a single gift"
  end

  test "a stage nobody can catch is sourced from the best-odds ancestor, not the nearest" do
    assert_equal "016", challenge.body_source(game, "018")
    assert_equal "010", challenge.body_source(game, "012"),
      "Caterpie at 50% beats Metapod at 25% as the body that walks up the line"
    assert_nil challenge.body_source(game, "010"), "the root of a line has no ancestor to draw on"
  end

  test "a species is queued at its best stop and only there" do
    forest = plan("viridian-forest")

    assert_equal [ "Caterpie", "Metapod" ], forest.queue.map(&:name)
    assert_equal 3, forest.bodies
    assert_equal [ "Pidgey", "Pidgeotto" ], forest.boxed.map(&:name),
      "Route 1 and Route 21 own these, so the forest only points at them"
  end

  test "a page shared by several stops lists each species once, at the stop worth the walk" do
    leg = plan("leg-04")
    oddish = leg.entries.select { |entry| entry.dex == "043" }

    assert_equal 1, oddish.size, "Oddish is on Route 24 and Route 25 but owes one row"
    assert_equal "route-24", oddish.first.at
    assert_equal 3, oddish.first.qty
    assert_equal 10, leg.entries.size
    assert_equal [ "Bulbasaur", "Charmander", "Oddish", "Bellsprout" ], leg.queue.map(&:name)
  end

  test "a species is grouped by how you would really get it here, not by whether it spawns" do
    catch_here, evolving = plan("leg-09").groups

    assert_includes catch_here.tiles.map(&:name), "Venonat", "10% in the grass is worth the walk"
    assert_includes evolving.tiles.map(&:name), "Venomoth",
      "Venomoth spawns at 1%, so the honest route is levelling the Venonat"
    refute_includes catch_here.tiles.map(&:name), "Venomoth"
  end

  test "a species catchable only past this window is named by its evolution, not its far spawn" do
    forest = plan("viridian-forest")
    fearow = forest.earlier.find { |tile| tile.name == "Fearow" }

    assert_equal "walkthrough.ui.where_evolve", fearow.where_key,
      "Route 17 is ten legs away, so before Brock the only Fearow is a levelled Spearow"
    assert_equal "Spearow", fearow.where_args[:name]
    assert_equal "walkthrough.ui.step_level", fearow.via_key
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

  test "the due count stays global even though the lists reset at each badge" do
    assert_equal 17, plan("viridian-forest").due_count
    assert_operator plan("leg-04").due_count, :>, plan("viridian-forest").due_count
    assert_equal challenge.registerable(game, "cerulean-city").size, plan("leg-04").due_count
  end

  test "locked names what the page unlocks but the window cannot register" do
    forest = plan("viridian-forest")

    assert_equal [ "Raichu", "Nidoqueen", "Nidoking" ], forest.locked.map(&:name)
    assert_equal [ "Raichu", "Golem", "Alakazam", "Machamp", "Gengar" ],
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

  test "a page with nothing to catch and nothing owed renders no challenge at all" do
    %w[ss-anne rocket-hideout].each do |slug|
      refute plan(slug).any?, "#{slug} has no species of its own"
      assert_empty plan(slug).entries
    end
  end

  test "a page can owe an Oak reminder without owing a single catch" do
    gym = plan("leg-13")

    refute gym.living?
    assert gym.oak?
    assert_equal 8, gym.earlier.size
  end

  test "every leg builds a plan whose queue never outruns the species on the page" do
    game.legs.each do |leg|
      page = game.plan_for(leg)

      assert_operator page.queue.size, :<=, page.entries.size, leg.slug
      assert_equal page.entries.map(&:dex).uniq, page.entries.map(&:dex), "#{leg.slug} repeats a species"
      assert page.window, "#{leg.slug} sits outside every window"
    end
  end
end
