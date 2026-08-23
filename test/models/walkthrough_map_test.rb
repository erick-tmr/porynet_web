require "test_helper"

class WalkthroughMapTest < ActiveSupport::TestCase
  def game = Walkthrough.find!("yellow")
  def location(slug) = game.locations.find { |l| l.slug == slug }
  def forest_map = location("viridian-forest").area_maps.first

  # Every stop pair that renders one map between them, which is every way the guide shows the
  # same errand twice.
  def shared_map_pairs
    by_map = Hash.new { |hash, key| hash[key] = [] }
    game.locations.each { |loc| loc.area_maps.each { |map| by_map[map.name] << loc } }
    by_map.values.select { |locs| locs.size > 1 }.flat_map { |locs| locs.combination(2).to_a }.uniq
  end

  # Everything on a stop's page that a player can tick off as collected, by the name on its card.
  def ticks_by_name(loc)
    (loc.steps.flat_map { |step| step.items + step.hidden } + loc.later)
      .group_by(&:name).transform_values { |cards| cards.map(&:tick).to_set }
  end

  # [map name, letter] for every trainer pin a stop's steps name, in the order they name them.
  def trainer_marks(loc)
    loc.steps.flat_map do |step|
      step.marks.filter_map do |name, key|
        [ step.pins.fetch(name).split("/").first, key ] if key.start_with?("T")
      end
    end
  end

  def marker(**overrides)
    Walkthrough::MapMarker.new(
      **{ id: "item-1-2", cat: "item", name: "Potion", x: 10.0, y: 20.0, align: "r", ref: "POTION" }
        .merge(overrides)
    )
  end

  test "manifest is parsed once and handed back frozen" do
    first = Walkthrough::Yellow.manifest

    assert_same first, Walkthrough::Yellow.manifest
    assert_predicate first, :frozen?
  end

  test "an area map carries the markers the generator read out of the game" do
    map = forest_map

    assert_equal "viridian-forest", map.name
    assert_equal [ 544, 768 ], [ map.width, map.height ]
    assert_equal({ "trainer" => 5, "item" => 3, "hidden" => 2, "exit" => 2 }, map.marker_counts)
    assert_equal 10, map.tickable_count   # the two exits are signposts, not chores
    assert_predicate map, :markers?
  end

  test "marker positions are percentages of the rendered image" do
    antidote = forest_map.markers.find { |marker| marker.id == "hidden-16-42" }

    assert_equal "Antidote", antidote.name
    assert_in_delta 48.529, antidote.x, 0.001
    assert_in_delta 88.542, antidote.y, 0.001
  end

  test "an exit is keyed, points the way it leaves, and cannot be ticked" do
    south = forest_map.markers.find { |marker| marker.id == "exit-15-47" }

    assert_equal "south", south.edge
    assert_equal "E2", south.key, "the legend needs a handle for it like every other row"
    assert_equal "▼", south.glyph_or_key, "but the pin still shows which way it goes"
    assert_equal 50.0, south.x, "a four-tile gate sits at the centre of its tiles"
    refute_predicate south, :tickable?
  end

  # The drawn way round an arrow-tile floor. The points come out of the game (tools/maps/
  # spinners.py reads the pushes each arrow tile applies), so what is checked here is the handling:
  # that a floor with no maze carries no line, and that a leg hands the view what an SVG needs.
  test "an arrow-tile floor carries the way round it, and an ordinary one carries none" do
    b2f = location("rocket-hideout").area_maps.find { |area| area.floor == "B2F" }

    assert_predicate b2f, :route?
    assert_equal 8, b2f.route_legs.size, "one leg per stretch between the stops the walk names"
    refute_predicate forest_map, :route?, "the forest has no arrows to solve"
    assert_empty forest_map.route_legs
  end

  test "a leg gives the view its polyline, its arrowhead and a colour to tell it apart by" do
    leg = Walkthrough::RouteLeg.new(points: [ [ 8, 8 ], [ 24, 8 ], [ 24, 40 ] ], n: 2)

    assert_equal "8,8 24,8 24,40", leg.line
    assert_equal [ 24, 40 ], leg.tip
    assert_equal 2, leg.hue
    assert_in_delta 90.0, leg.heading, 0.01, "the last step runs south, so the head points south"
  end

  # Five hues, so the sixth leg of a long floor starts the palette again rather than running out.
  test "a leg of one cell points east, and the palette wraps" do
    assert_in_delta 0.0, Walkthrough::RouteLeg.new(points: [ [ 8, 8 ] ], n: 1).heading, 0.01
    assert_equal 1, Walkthrough::RouteLeg.new(points: [ [ 8, 8 ] ], n: 6).hue
  end

  test "markers_in narrows to one category" do
    assert_equal 3, forest_map.markers_in("item").size
    assert_empty forest_map.markers_in("nonsense")
  end

  test "a trainer marker is keyed and tickable" do
    first = forest_map.markers_in("trainer").first

    assert_equal "T1", first.glyph_or_key
    assert_predicate first, :key?
    assert_predicate first, :tickable?
  end

  test "a marker with neither glyph nor key has nothing to show" do
    assert_nil marker.glyph_or_key
    assert_equal "X", marker(key: "X").glyph_or_key
    assert_equal "▲", marker(key: "X", glyph: "▲").glyph_or_key, "a glyph wins over a key"
  end

  test "a map wider than half again its height takes the landscape template" do
    assert_predicate location("route-3").area_maps.first, :landscape?, "1120x288 is a horizontal strip"
    refute_predicate forest_map, :landscape?, "544x768 is taller than wide"

    square = location("silph-co").area_maps.find { |area| area.name == "silph-co-11f" }
    refute_predicate square, :landscape?, "a square floor stays in the side-by-side split"
  end

  test "the NPC overlay joins item-givers and easter eggs onto the map they stand on" do
    fisher = location("pallet-town").area_maps.first.markers.find { |m| m.id == "npc-technology" }

    assert_equal "npc", fisher.cat
    assert_equal "Technology!", fisher.name
    assert_equal "N1", fisher.key, "an NPC numbers from N1, clear of every other category"
    assert_in_delta 57.5, fisher.x, 0.001, "grid (11,14) centred on the 320px-wide map"
    assert_in_delta 80.556, fisher.y, 0.001
    assert_predicate fisher, :key?
    assert_predicate fisher, :note?
    refute_predicate fisher, :tickable?, "an NPC is a signpost, not a chore"
  end

  # The letters run 1, 2, 3 down the page because the pins are lettered along the walk and the steps
  # were written along the same walk: the western Poké Ball is the first thing you can pick up, and
  # the Antidote by the gate the first thing you can feel for. Read off the map file they came out
  # I3, I1, I2, so a reader following the steps watched the letters jump about.
  test "every card carries the key its pin wears, so the two name one thing" do
    forest = location("viridian-forest")
    items = forest.steps.flat_map(&:items)
    hidden = forest.steps.flat_map(&:hidden)

    assert_equal [ "I1", "I2", "I3" ], items.map(&:key)
    assert_equal "viridian-forest/item-1-31", items.first.tick
    assert_equal({ "Antidote" => "H1", "Potion" => "H2" }, hidden.to_h { |h| [ h.name, h.key ] })
  end

  # The check that keeps tools/maps/paths.py honest. The pins are lettered by a flood over the
  # game's own collision, which walks straight through boulders, spin tiles and barred doors
  # because the shipped map does not know they are shut. The steps are the real route, so wherever
  # the two disagree the route names the landmarks it turns at (paths.ROUTES) until they agree.
  # A letter series that counts backwards down a page is the bug this catches.
  test "every page collects its items in letter order" do
    backwards = game.locations.flat_map do |loc|
      loc.steps.flat_map { |step| step.items + step.hidden }
        .filter_map { |item| [ item.tick&.split("/")&.first, item.key ] if item.key }
        .group_by { |map, key| [ map, key[0] ] }
        .filter_map do |(map, letter), pairs|
          numbers = pairs.map { |_map, key| key[1..].to_i }
          "#{loc.slug} #{map} #{letter}: #{numbers.inspect}" if numbers != numbers.sort
        end
    end

    assert_empty backwards, "these pages count their letters backwards"
  end

  # The same check for the trainers a step points at by pin: Viridian Forest names five of them,
  # and a reader walking the steps meets T1 through T5 in that order. Per map, like the items,
  # because a stop that walks several floors gets a T1 on each of them: the Rocket Hideout takes
  # its four basements in seven visits, so its page reads T1 five times before it is done.
  test "every page meets the trainers its steps name in letter order" do
    backwards = game.locations.flat_map do |loc|
      trainer_marks(loc).group_by(&:first).filter_map do |map, pairs|
        numbers = pairs.map { |_map, key| key[1..].to_i }
        "#{loc.slug} #{map}: #{numbers.inspect}" if numbers != numbers.sort
      end
    end

    assert_empty backwards, "these pages meet their trainers out of order"
  end

  test "a step that names a pin resolves it to the key that pin wears today" do
    approach = location("route-4-mt-moon")
    center = approach.area_maps.first.markers.find { |m| m.id == "exit-11-5" }

    assert_equal({ center: center.key }, approach.steps.first.marks)
    assert_equal "Mt. Moon Pokecenter", center.name
  end

  test "every step that names pins ends up with a key for each of them" do
    unresolved = game.locations.flat_map(&:steps).reject { |s| s.pins.keys == s.marks.keys }

    assert_empty unresolved.map(&:title_key),
      "a step kept an unresolved pin, so its prose would print a raw %{token}"
  end

  test "a pin knows the step that picks it up, so the map can point back at the prose" do
    pins = forest_map.markers.to_h { |m| [ m.id, m.step ] }

    assert_equal 3, pins.fetch("item-1-31"), "the Poké Ball is step 3's errand"
    assert_equal 6, pins.fetch("hidden-1-18")
    assert_nil pins.fetch("trainer-2-41"), "a trainer belongs to the location, not to one step"
    assert_nil pins.fetch("exit-1-0")
  end

  # The Moon Stone is I2 because Route 2's two balls are lettered the way the Diglett's Cave detour
  # walks them: the HP Up first, then the Moon Stone below it.
  test "a locked later item names its pin, and names none when the game gives it no ball" do
    route_2 = location("route-2").later.to_h { |l| [ l.name, l.key ] }

    assert_equal "I2", route_2.fetch("Moon Stone")
    assert_nil route_2.fetch("HM05 Flash"), "Flash is handed over by Oak's aide, not lying on a tile"
  end

  # The locked card, the map pin and the step that finally collects it are one item seen three
  # times, so all three tick the same id. A ball takes it from its pin, a stash from its hidden
  # pin, and only an NPC gift, which the map draws nowhere, falls back to an id of its own.
  test "a locked later item ticks against its own pin, not its slot on the page" do
    route_2 = location("route-2").later.to_h { |l| [ l.name, l.tick ] }
    step = location("digletts-cave").steps.flat_map(&:items).find { |i| i.name == "Moon Stone" }

    assert_equal "route-2/item-13-54", route_2.fetch("Moon Stone")
    assert_equal "route-2/item-13-45", route_2.fetch("HP Up")
    assert_equal route_2.fetch("Moon Stone"), step.tick
    assert_equal "vermilion-city/hidden-14-11", location("vermilion-city").later.sole.tick,
      "the Max Ether is a hidden stash, and the map pins those too"
  end

  test "an NPC gift, which no map pin holds, is keyed to the place that hands it over" do
    flash = location("route-2").later.find { |l| l.name == "HM05 Flash" }
    collected = location("digletts-cave").steps.flat_map(&:items).find { |i| i.name == "HM05 Flash" }

    assert_nil flash.key, "Oak's aide hands it over indoors, so no pin wears a letter for it"
    assert_equal "route-2/gift-flash", flash.tick
    assert_equal flash.tick, collected.tick
    assert_equal "viridian-city/gift-tm42",
      location("digletts-cave").steps.flat_map(&:items).find { |i| i.name == "TM42 Dream Eater" }.tick
  end

  # Borrowing another stop's map is the only thing that puts one errand on two pages, so it is
  # also the only way two cards can drift onto separate progress ids and quietly stop syncing.
  test "two stops that share a map tick one id per item" do
    pairs = shared_map_pairs.sort_by { |a, b| [ a.slug, b.slug ] }
    clashes = pairs.flat_map do |a, b|
      left, right = ticks_by_name(a), ticks_by_name(b)
      (left.keys & right.keys).reject { |name| left[name] == right[name] }
        .map { |name| "#{name}: #{a.slug} ticks #{left[name].to_a}, #{b.slug} ticks #{right[name].to_a}" }
    end

    assert_empty clashes, "one item, two progress ids: ticking it on one page leaves the other unticked"
    assert_equal [ %w[celadon-city celadon-city-return], %w[pewter-city digletts-cave],
                   %w[route-10 route-10-south], %w[route-2 digletts-cave],
                   %w[route-4-mt-moon route-4], %w[vermilion-city vermilion-city-return],
                   %w[viridian-city digletts-cave] ],
      pairs.map { |a, b| [ a.slug, b.slug ] }, "every stop that renders another stop's map"
  end

  test "a stop that walks off its own map borrows the maps it steps onto" do
    borrowed = location("digletts-cave").area_maps

    assert_equal %w[digletts-cave route-2 viridian-city pewter-city], borrowed.map(&:name)
    assert_nil borrowed.first.title, "its own map is titled by the page"
    assert_equal [ "Route 2", "Viridian City", "Pewter City" ], borrowed.drop(1).map(&:title)
    assert_equal "Route 2", borrowed[1].caption
    assert_predicate borrowed[1], :captioned?
    refute_predicate borrowed.first, :captioned?
  end

  test "borrowing a map leaves the lender's own page untouched" do
    lender = location("route-2").area_maps.sole

    assert_nil lender.title
    assert_nil lender.markers.find { |m| m.id == "item-13-54" }.step,
      "Route 2 walks past the Moon Stone; the Diglett's Cave detour is what collects it"
    assert_equal 8, location("digletts-cave").area_maps[1]
      .markers.find { |m| m.id == "item-13-54" }.step
  end

  # The Cut detour crosses four maps, so one wall of steps over one pile of maps leaves the reader
  # working out which map each step is on. Steps that name their map let the page draw each map
  # with only the steps taken there.
  test "a stop that names its steps' maps groups them map by map" do
    groups = location("digletts-cave").step_groups

    assert_equal %w[digletts-cave route-2 viridian-city pewter-city],
      groups.filter_map { |area, _steps| area&.name }
    assert_equal [ 3, 6, 1, 4 ], groups.map { |_area, steps| steps.size }
    assert_equal "pewter-city", groups.last.first.name,
      "the sign-off names no map, so it stays in the block before rather than breaking the rail"
    assert_equal (1..14).to_a, groups.flat_map(&:last).map(&:n), "every step lands in exactly one group"
  end

  test "a stop whose steps name no map renders as one block" do
    loc = location("rock-tunnel")

    assert_predicate loc.area_maps.size, :positive?
    assert_empty loc.step_groups, "no grouping to do, so the page keeps its single steps section"
    refute_predicate loc.steps.first, :map?
  end

  # The Diglett's Cave stop walks off its own map and on through Route 2, so a block about what
  # lives in the cave has to be drawn under the cave rather than at the foot of a page that ends
  # two maps away from it.
  test "a grind spot pinned to a map is drawn with that map, not at the end of the walk" do
    grind = location("digletts-cave").grind
    cave, route_2 = location("digletts-cave").area_maps.first(2)

    assert grind.after?(cave)
    refute grind.after?(route_2)
    refute grind.after?(nil)
  end

  test "a curated NPC pin marks the giver the map data cannot name" do
    fisher = location("viridian-city").area_maps.first.markers.find { |m| m.id == "npc-tm42" }

    assert_equal "npc", fisher.cat
    assert_equal "TM42 Dream Eater", fisher.name
    refute_predicate fisher, :tickable?
    assert_equal "N1", fisher.key
  end

  test "each category counts from one, so no two pins on a map share a key" do
    map = location("route-24").area_maps.first
    keys = map.markers.map(&:key)

    assert_equal %w[T1 T2 T3 T4 T5 T6 T7], map.markers_in("trainer").map(&:key)
    assert_equal %w[I1], map.markers_in("item").map(&:key)
    assert_equal %w[E1 E2], map.markers_in("exit").map(&:key)
    assert_equal "N1", map.markers.find { |m| m.cat == "npc" }.key,
      "an NPC starts its own N series rather than borrowing the trainers'"
    assert_equal keys, keys.uniq, "a key names one thing on a map or it names nothing"
  end

  test "an NPC pin is left out of the tickable count and carries a note only it and exits have" do
    map = location("route-24").area_maps.first
    npc = map.markers.find { |m| m.cat == "npc" }

    assert_not_nil npc, "the Nugget Bridge giver sits on the route"
    assert_equal map.markers.count(&:tickable?), map.tickable_count
    refute_predicate map.markers_in("trainer").first, :note?
    refute_predicate marker, :note?
  end

  test "an NPC on the right half of the map flips its label to the left" do
    right = Walkthrough::Yellow.npc_marker({ "grid" => [ 18, 2 ] }, 320, 288, "A")  # x = 92.5%
    left = Walkthrough::Yellow.npc_marker({ "grid" => [ 2, 2 ] }, 320, 288, "A")     # x = 12.5%

    assert_equal "l", right.align
    assert_equal "r", left.align
  end

  test "NPC keys number from one, matching the generator's own series" do
    assert_equal "N1", Walkthrough::Yellow.key_letter(0)
    assert_equal "N3", Walkthrough::Yellow.key_letter(2)
  end

  test "an area map defaults to no name and no markers" do
    bare = Walkthrough::AreaMap.new(image: "a.png", width: 1, height: 1, floor: "")

    assert_equal "", bare.name
    assert_empty bare.markers
    refute_predicate bare, :markers?
    refute_predicate bare, :captioned?
    assert_nil bare.title
    assert_equal({}, bare.marker_counts)
    assert_equal 0, bare.tickable_count
  end

  test "a trainer given its map object takes the key that object's pin carries" do
    lass = location("viridian-forest").trainers.find { |trainer| trainer.cls == "LASS" }

    assert_equal "LASS:19", lass.opp
    assert_equal "T1", lass.marker_key
    assert_predicate lass, :marker_key?
  end

  test "every keyed trainer letter matches a marker on the same map" do
    loc = location("viridian-forest")
    pins = loc.area_maps.flat_map(&:markers).select(&:key?).to_h { |marker| [ marker.key, marker.ref ] }

    loc.trainers.select(&:marker_key?).each do |trainer|
      assert_equal trainer.opp, pins[trainer.marker_key],
        "#{trainer.cls} shows #{trainer.marker_key} but that pin is #{pins[trainer.marker_key]}"
    end
  end

  test "a gym leader claims the key of its own pin on the gym floor" do
    brock = location("pewter-city").gym.leader

    assert_equal "BROCK:1", brock.opp
    assert_equal "T2", brock.marker_key
    assert_predicate brock, :marker_key?
  end

  test "a gym city moves its gym floor into the gym section and pins its trainers on it" do
    loc = location("pewter-city")

    assert(loc.area_maps.none? { |area| area.floor == "Gym" }, "the gym floor moves into the gym section")
    assert_match(/pewter-city-gym/, loc.gym.shot.image)
    assert_equal %w[T1 T2], loc.gym.pins.map(&:key), "the gym map draws a keyed pin per trainer"
    assert(loc.gym.pins.all? { |pin| pin.cat == "trainer" }, "only trainers are pinned")
  end

  test "a gym whose floor the manifest never drew pins nobody" do
    gym = location("pewter-city").gym.with(area: nil)

    refute_predicate gym, :area?
    assert_empty gym.pins
  end

  test "a location with no manifest entry still builds" do
    loc = Walkthrough::Yellow.attach_maps(location("viridian-forest"), [])

    assert_empty loc.area_maps
    assert_equal 5, loc.trainers.size, "the roster still supplies its cards"
  end
end
