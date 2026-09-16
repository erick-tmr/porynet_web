require "test_helper"

class WalkthroughLegacyTest < ActiveSupport::TestCase
  def game = Walkthrough.find!("yellow-legacy")
  def location(slug) = game.locations.find { |l| l.slug == slug }
  def pallet_map = location("pallet-town").area_maps.first
  def changed_rules = what_changed("pallet-town")

  def what_changed(slug) = location(slug).trivia.find { |t| t.anchor.end_with?("what-changed") }

  test "the two Pallet locals Legacy rewrote stand on the town map as un-tickable pins" do
    npcs = pallet_map.markers_in("npc")

    assert_equal %w[N1 N2], npcs.map(&:key), "lettered north to south, clear of every other series"
    assert_equal [ "Running Shoes", "Bigger Bag" ], npcs.map(&:name)
    assert_in_delta 17.5, npcs.first.x, 0.001, "the girl's grid (3,8) on the 320px-wide map"
    assert_in_delta 47.222, npcs.first.y, 0.001
    assert npcs.none?(&:tickable?), "a briefing is a signpost, not a chore"
    assert npcs.all?(&:note?), "each pin carries the change the NPC explains"
  end

  # Vanilla's fisher talks up PC item storage. Legacy gave him a backpack speech, so reusing
  # Yellow's note would put words in his mouth that this game does not have.
  test "the Pallet overlay says what Legacy's NPCs say, not what Yellow's do" do
    notes = pallet_map.markers_in("npc").map(&:note)

    assert_equal %w[map_npc_pallet_running_shoes map_npc_pallet_bigger_bag], notes
    assert_not_includes Walkthrough::YellowLegacy.npc_overlay.fetch("pallet-town").map { |n| n["note"] },
      "map_npc_pallet_technology"
  end

  test "Pallet carries the Eevee trivia and the What Changed briefing, in that order" do
    assert_equal [ Walkthrough::Gen1Guide::RIVAL_EEVEE_ANCHOR,
                   Walkthrough::YellowLegacy.changed_anchor("pallet-town") ],
      location("pallet-town").trivia.map(&:anchor)
    assert_equal 1, Walkthrough::Yellow.game.locations.find { |l| l.slug == "pallet-town" }.trivia.size,
      "vanilla Yellow has nothing to brief anyone on"
  end

  test "the briefing's marks resolve to the pins its sentence points at" do
    assert_equal({ shoes: "N1", bag: "N2", lab: "E3" }, changed_rules.marks)
  end

  # Legacy shifts the whole rod chain one giver forward, so the catch lists that a rod opens have
  # to move with it: Viridian's fish are live on the page that hands you the rod, not greyed out
  # until Vermilion the way vanilla leaves them.
  test "each rod opens its catches on the stop that actually hands it over" do
    viridian = location("viridian-city")
    old_rod = viridian.encounters.select { |enc| enc.how == "OLD ROD" }

    assert_equal [ "Goldeen", "Poliwag" ], old_rod.map(&:name).sort
    assert old_rod.all? { |enc| enc.unlocked_from <= viridian.order }
    assert_equal %w[118 060], viridian.dex_list, "the Old Rod pair counts here now"
    assert_equal 17, viridian.encounters.find { |enc| enc.how == "GOOD ROD" }.unlocked_from,
      "the Good Rod moved up to Vermilion, so its fish wait for that page"
  end

  test "Viridian's Mart hands over the Old Rod, in its own step with its own shot" do
    step = location("viridian-city").steps.find { |s| s.items.any? { |i| i.name == "Old Rod" } }

    assert_equal 5, step.n, "after stocking the Mart, while the player is still standing in it"
    assert_equal 8, location("viridian-city").steps.size
    assert_equal "walkthrough/yellow-legacy/scenes/viridian-mart-old-rod.png", step.shots.first.image
  end

  test "the Vermilion guru hands the Good Rod, and Fuchsia's house has no rod left to give" do
    vermilion = location("vermilion-city").steps.first.items.map(&:name)

    assert_equal [ "Bike Voucher", "Good Rod" ], vermilion
    assert_empty location("fuchsia-city").steps.find { |s| s.n == 2 }.items,
      "that house gives the fossil Pokémon you passed up, not a rod"
  end

  # Every stop whose bystanders brief you on a rule carries its own section, and the sentence in it
  # points at the pin the NPC stands on.
  test "each briefed stop grows a What Changed section whose marks resolve to real pins" do
    stops = Walkthrough::YellowLegacy::WHAT_CHANGED.keys

    assert_equal 12, stops.size

    stops.each do |slug|
      block = what_changed(slug)

      assert_not_nil block, "#{slug} declares a section but does not carry one"
      assert_equal block.pins.keys.sort, block.marks.keys.sort, "#{slug} left a pin unresolved"
      assert block.marks.values.all? { |key| key.match?(/\A[NEIHT]\d+\z/) }, block.marks.inspect
      assert_predicate block, :tag?
    end
  end

  test "a section separates what Legacy altered from what it only explains" do
    assert_equal %w[yes yes yes yes na], what_changed("viridian-city").facts.map(&:state)
    assert_equal %w[na], what_changed("cerulean-city").facts.map(&:state),
      "the crit rule is Gen 1's, not Legacy's, so it never wears a change mark"
  end

  test "vanilla Yellow grows no such section" do
    yellow = Walkthrough.find!("yellow")
    blocks = yellow.locations.flat_map(&:trivia).select { |t| t.anchor.end_with?("what-changed") }

    assert_empty blocks
  end

  # A stop's rate has to be one you can actually make there. Viridian lists Poliwag at 100% on the
  # Super Rod, which arrives 28 stops later, and counting it sent the plan here while the star sat
  # on Route 23. The two now agree because both read armed slots only.
  test "a stop is judged on the odds you can reach there, not on a rod you do not own yet" do
    viridian = location("viridian-city")

    assert_equal 50, Walkthrough::Challenge.stop_rate(viridian, "060"),
      "the Super Rod slot here is unreachable until Route 12"
    assert_equal "route-23", game.best_catches["060"].slug
    assert_nil game.best_catch_here(viridian, viridian.encounters.find { |e| e.dex == "060" }),
      "so the star belongs to Route 23, and this page points at it instead"
  end

  # Route 3 and Route 14 say their piece as an after-battle line, so the section cites the trainer
  # already pinned there rather than dropping a second marker on the same tile.
  test "a rule a trainer tells you cites that trainer's pin, not a new one" do
    assert_equal({ youngster: "T3" }, what_changed("route-3").marks)
    assert_equal({ cooltrainer: "T2" }, what_changed("route-14").marks)

    %w[route-3 route-14].each do |slug|
      assert_empty location(slug).area_maps.flat_map(&:markers).select { |m| m.cat == "npc" },
        "#{slug} should gain no NPC pin: the speaker is already a trainer on the map"
    end
  end

  test "Fuchsia's rod house is recorded as the fossil giver it became" do
    assert_equal({ house: "E8" }, what_changed("fuchsia-city").marks)
    refute_includes location("fuchsia-city").encounters.map(&:dex), "140",
      "the gift is written up but not yet tracked as a catch, which the note says out loud"
  end

  test "every gym with a guide standing in it pins him on the gym floor" do
    guides = game.locations.filter_map { |loc| loc.gym&.area }
      .filter_map { |area| area.markers.find { |m| m.id == "npc-gym-guide" } }

    assert_equal 7, guides.size, "Celadon's guide stands in the Game Corner, not the gym"
    assert guides.all? { |m| m.key == "N1" }
    assert guides.none?(&:tickable?)
  end

  test "the briefing rows separate what Legacy added from what it took away" do
    assert_equal %w[yes yes yes yes no], changed_rules.facts.map(&:state)
    assert_equal "✕", changed_rules.facts.last.mark, "Bug lost its edge over Poison"
    assert_equal "walkthrough/yellow-legacy/scenes/pallet-running-shoes.png",
      changed_rules.shot.image
  end
end
