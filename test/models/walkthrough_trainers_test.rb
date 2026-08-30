require "test_helper"

class WalkthroughTrainersTest < ActiveSupport::TestCase
  SCRIPTED = { "ss-anne" => "RIVAL1:1", "rocket-hideout" => "GIOVANNI:1",
               "silph-co" => "GIOVANNI:2" }.freeze

  def game = Walkthrough.find!("yellow")
  def location(slug) = game.locations.find { |l| l.slug == slug }
  def all_cards = game.locations.flat_map { |l| l.trainers + gym_cards(l) }
  # A gym and the Fighting Dojo both hold their fights behind one door, so both count as cards.
  def gym_cards(loc) = halls(loc).flat_map { |hall| hall.trainers + [ hall.leader ] }
  def halls(loc) = [ loc.gym, loc.dojo ].compact

  test "the roster is parsed once and handed back frozen" do
    first = Walkthrough::Yellow.roster

    assert_same first, Walkthrough::Yellow.roster
    assert_predicate first, :frozen?
  end

  # A stop the guide walks twice (Route 4 around Mt. Moon, Vermilion around the S.S. Anne) splits
  # one map's roster across its two passes, so the cards are counted over both.
  test "every trainer the game fields has a card" do
    counts = Walkthrough::Yellow.roster.fetch("trainers").transform_values(&:size)

    counts.each do |slug, wanted|
      passes = game.locations.select { |loc| loc.slug == slug || Walkthrough::Yellow::MAP_SOURCE[loc.slug] == slug }
      cards = passes.sum { |loc| loc.trainers.size + gym_cards(loc).size }
      assert_operator cards, :>=, wanted, slug
    end
  end

  test "a generated card carries everything a card needs" do
    all_cards.each do |card|
      assert card.cls.present?, card.inspect
      assert_operator card.reward, :>, 0, card.cls
      assert_includes 1..6, card.team.size, card.cls
      assert card.sprite.present?, card.cls
      assert card.team.all? { |mon| mon[:dex].match?(/\A\d{3}\z/) && mon[:lvl].positive? }, card.cls
    end
  end

  # Both the letters and the card order come off the walk (tools/maps/paths.py measures it), so a
  # route entered at one end runs T1 to T10 straight down the page.
  test "a route that authored nothing is filled from the game" do
    route = location("route-11")

    assert_equal 10, route.trainers.size
    assert_equal %w[T1 T2 T3 T4 T5 T6 T7 T8 T9 T10], route.trainers.map(&:marker_key)
    assert(route.trainers.all? { |card| card.where.map? })
  end

  # Route 10 is one map split down the middle by Rock Tunnel and walked as two pages, so each half
  # is walked from its own mouth: the north pair from Route 9, the four below from the tunnel's
  # south mouth. Both pages draw that one map, and a pin can only wear one letter, so the lettering
  # runs over the whole route once and the second page picks up where the first left off.
  test "a stop walked twice letters each pass from the door it comes in by" do
    assert_equal %w[T1 T2], location("route-10").trainers.map(&:marker_key)
    assert_equal %w[T3 T4 T5 T6], location("route-10-south").trainers.map(&:marker_key)
  end

  # A gym is one room off one door, so it letters from the door inwards and always ends on the
  # leader: the Jr. Trainer is T1 and Brock, at the back of the room, is T2. The map file declares
  # Brock first.
  test "a gym letters its trainers from the door inwards" do
    gym = location("pewter-city").gym

    assert_equal %w[T1], gym.trainers.map(&:marker_key)
    assert_equal "T2", gym.leader.marker_key
  end

  test "an authored card replaces its generated twin rather than joining it" do
    forest = location("viridian-forest")
    pins = forest.area_maps.flat_map(&:markers).count { |marker| marker.cat == "trainer" }

    assert_equal pins, forest.trainers.size
  end

  test "a scripted battle keeps the team a human wrote, not the one its map object names" do
    SCRIPTED.each do |slug, opp|
      card = (location(slug).trainers + gym_cards(location(slug))).find { |card| card.opp == opp }
      assert card, "#{slug} lost its override for #{opp}"
      assert card.name.present?, "#{opp} should be a named story battle"
      assert card.battle&.map?, "#{opp} should keep its hand-framed battle shot"
    end
  end

  test "the SS Anne rival is not the level five Eevee its map object points at" do
    rival = location("ss-anne").trainers.find { |card| card.opp == "RIVAL1:1" }

    assert_equal 4, rival.team.size
    assert_equal 1300, rival.reward
  end

  test "an authored card the game never declares is kept and follows the generated ones" do
    plateau = location("indigo-plateau")

    assert_equal 5, plateau.trainers.size
    assert(plateau.trainers.all? { |card| card.marker_key.nil? })
    assert_equal [ "Lorelei", "Bruno", "Agatha", "Lance", "Blue" ], plateau.trainers.map(&:name)
  end

  test "a location with no trainers at all stays empty" do
    assert_empty location("route-1").trainers
  end

  # Erika takes T5 rather than the last letter: Celadon's gym keeps beating you to her with three
  # more trainers deeper in the room, and the lettering follows the walk, not the billing.
  test "gym trainers come from the gym floor and claim its pin keys" do
    gym = location("celadon-city-return").gym

    assert_equal 7, gym.trainers.size
    assert_equal %w[T1 T2 T3 T4 T6 T7 T8], gym.trainers.map(&:marker_key).sort
    assert_equal "T5", gym.leader.marker_key
    assert_equal "Erika", gym.leader.name
    assert_equal "ERIKA:1", gym.leader.opp
  end

  test "the gym leader keeps the badge context a human wrote" do
    brock = location("pewter-city").gym.leader

    assert_equal "Brock", brock.name
    assert brock.battle&.map?
    assert_equal 1188, brock.reward
  end

  test "Viridian Gym files its trainers under the gym even though its map has no floor" do
    viridian = location("viridian-gym")

    assert_empty viridian.trainers
    assert_equal 8, viridian.gym.trainers.size
    assert_equal "Giovanni", viridian.gym.leader.name
  end

  test "the SS Anne pins every trainer now that every deck is drawn" do
    ship = location("ss-anne")

    assert_equal 17, ship.trainers.size
    assert_equal "Blue", ship.trainers.first.name
    pinless = ship.trainers.reject { |card| card.marker_key }
    assert_equal [ "RIVAL" ], pinless.map(&:cls),
      "only Blue, who is walked in by script rather than standing on the map"
  end

  test "a card ticks under the same key as its pin on the map" do
    route = location("route-3")
    card = route.trainers.first
    pin = route.area_maps.flat_map(&:markers).find { |marker| marker.ref == card.opp }

    assert_equal "route-3/#{pin.id}", card.tick
  end

  test "an authored card with no map object ticks under its own key" do
    rival = location("pallet-town").trainers.first

    assert_nil rival.opp
    assert_nil rival.tick, "nothing generated claims it, so the view falls back to its position"
  end

  test "dense_trainers? turns on past a handful" do
    assert_predicate location("route-11"), :dense_trainers?
    refute_predicate location("route-1"), :dense_trainers?
  end

  test "class labels translate the game's spelling, and pass the rest through" do
    assert_equal "BUG CATCHER", Walkthrough::Yellow.class_label("BUG_CATCHER")
    assert_equal "TEAM ROCKET", Walkthrough::Yellow.class_label("ROCKET")
    assert_equal "POKéMANIAC", Walkthrough::Yellow.class_label("POKEMANIAC")
    assert_equal "HIKER", Walkthrough::Yellow.class_label("HIKER")
    assert_equal "BIRD KEEPER", Walkthrough::Yellow.class_label("BIRD_KEEPER")
  end
end
