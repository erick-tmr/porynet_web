require "test_helper"

class WalkthroughMapTest < ActiveSupport::TestCase
  def game = Walkthrough.find!("yellow")
  def location(slug) = game.locations.find { |l| l.slug == slug }
  def forest_map = location("viridian-forest").area_maps.first

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

  test "an exit is keyless, points the way it leaves, and cannot be ticked" do
    south = forest_map.markers.find { |marker| marker.id == "exit-15-47" }

    assert_equal "south", south.edge
    assert_equal "▼", south.glyph_or_key
    assert_equal 50.0, south.x, "a four-tile gate sits at the centre of its tiles"
    refute_predicate south, :key?
    refute_predicate south, :tickable?
  end

  test "markers_in narrows to one category" do
    assert_equal 3, forest_map.markers_in("item").size
    assert_empty forest_map.markers_in("nonsense")
  end

  test "a trainer marker is lettered and tickable" do
    first = forest_map.markers_in("trainer").first

    assert_equal "A", first.glyph_or_key
    assert_predicate first, :key?
    assert_predicate first, :tickable?
  end

  test "a marker with neither glyph nor key has nothing to show" do
    assert_nil marker.glyph_or_key
    assert_equal "X", marker(key: "X").glyph_or_key
    assert_equal "▲", marker(key: "X", glyph: "▲").glyph_or_key, "a glyph wins over a letter"
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
    assert_equal "A", fisher.key, "a map with no trainers starts its people at A"
    assert_in_delta 57.5, fisher.x, 0.001, "grid (11,14) centred on the 320px-wide map"
    assert_in_delta 80.556, fisher.y, 0.001
    assert_predicate fisher, :key?
    assert_predicate fisher, :note?
    refute_predicate fisher, :tickable?, "an NPC is a signpost, not a chore"
  end

  test "an NPC's letter carries on from the trainers so the two never collide" do
    map = location("route-24").area_maps.first
    trainers = map.markers_in("trainer")
    npc = map.markers.find { |m| m.cat == "npc" }

    assert_equal 7, trainers.size
    assert_equal %w[A B C D E F G], trainers.map(&:key)
    assert_equal "H", npc.key, "the Nugget giver takes the letter after the last trainer"
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

  test "NPC letters run past Z the way the generator's do" do
    assert_equal "A", Walkthrough::Yellow.key_letter(0)
    assert_equal "Z", Walkthrough::Yellow.key_letter(25)
    assert_equal "AA", Walkthrough::Yellow.key_letter(26)
  end

  test "an area map defaults to no name and no markers" do
    bare = Walkthrough::AreaMap.new(image: "a.png", width: 1, height: 1, floor: "")

    assert_equal "", bare.name
    assert_empty bare.markers
    refute_predicate bare, :markers?
    refute_predicate bare, :floor?
    assert_equal({}, bare.marker_counts)
    assert_equal 0, bare.tickable_count
  end

  test "a trainer given its map object takes the letter that object's pin carries" do
    lass = location("viridian-forest").trainers.find { |trainer| trainer.cls == "LASS" }

    assert_equal "LASS:19", lass.opp
    assert_equal "D", lass.marker_key
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

  test "a trainer fought somewhere the location never draws carries no letter" do
    brock = location("pewter-city").gym.leader

    assert_equal "BROCK:1", brock.opp
    assert_nil brock.marker_key
    refute_predicate brock, :marker_key?
  end

  test "a gym city moves its gym floor into the gym section and keys nobody from it" do
    loc = location("pewter-city")

    assert(loc.area_maps.none? { |area| area.floor == "Gym" }, "the gym floor moves into the gym section")
    assert_match(/pewter-city-gym/, loc.gym.shot.image)
  end

  test "a location with no manifest entry still builds" do
    loc = Walkthrough::Yellow.attach_maps(location("viridian-forest"), [])

    assert_empty loc.area_maps
    assert_equal 5, loc.trainers.size, "the roster still supplies its cards"
  end
end
