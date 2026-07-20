require "test_helper"

class WalkthroughTrainersTest < ActiveSupport::TestCase
  # Battles the game picks a party for at run time, so the map object's party number is a
  # placeholder and the card must stay hand-authored. The SS Anne rival's object points at Rival1
  # party 1, which is a single level 5 Eevee: the Oak's Lab fight, not the one on the ship.
  SCRIPTED = { "ss-anne" => "RIVAL1:1", "rocket-hideout" => "GIOVANNI:1",
               "silph-co" => "GIOVANNI:2" }.freeze

  def game = Walkthrough.find!("yellow")
  def location(slug) = game.locations.find { |l| l.slug == slug }
  def all_cards = game.locations.flat_map { |l| l.trainers + gym_cards(l) }
  def gym_cards(loc) = loc.gym ? loc.gym.trainers + [ loc.gym.leader ] : []

  test "the roster is parsed once and handed back frozen" do
    first = Walkthrough::Yellow.roster

    assert_same first, Walkthrough::Yellow.roster
    assert_predicate first, :frozen?
  end

  test "every trainer the game fields has a card" do
    counts = Walkthrough::Yellow.roster.fetch("trainers").transform_values(&:size)

    counts.each do |slug, wanted|
      loc = location(slug)
      assert_operator loc.trainers.size + gym_cards(loc).size, :>=, wanted, slug
    end
  end

  test "a generated card carries everything a card needs" do
    all_cards.each do |card|
      assert card.cls.present?, card.inspect
      assert_operator card.reward, :>, 0, card.cls
      assert_includes 1..6, card.team.size, card.cls
      assert card.sprite.present?, card.cls
      assert card.team.all? { |m| m[:dex].match?(/\A\d{3}\z/) && m[:lvl].positive? }, card.cls
    end
  end

  test "a route that authored nothing is filled from the game" do
    route = location("route-11")

    assert_equal 10, route.trainers.size
    assert_equal %w[A B C D E F G H I J], route.trainers.map(&:marker_key)
    assert(route.trainers.all? { |t| t.where.map? })
  end

  test "an authored card replaces its generated twin rather than joining it" do
    forest = location("viridian-forest")
    pins = forest.area_maps.flat_map(&:markers).count { |m| m.cat == "trainer" }

    assert_equal pins, forest.trainers.size
  end

  test "a scripted battle keeps the team a human wrote, not the one its map object names" do
    SCRIPTED.each do |slug, opp|
      card = (location(slug).trainers + gym_cards(location(slug))).find { |t| t.opp == opp }
      assert card, "#{slug} lost its override for #{opp}"
      assert card.name.present?, "#{opp} should be a named story battle"
      assert card.battle&.map?, "#{opp} should keep its hand-framed battle shot"
    end
  end

  test "the SS Anne rival is not the level five Eevee its map object points at" do
    rival = location("ss-anne").trainers.find { |t| t.opp == "RIVAL1:1" }

    assert_equal 4, rival.team.size
    assert_equal 1300, rival.reward
  end

  test "an authored card the game never declares is kept and follows the generated ones" do
    plateau = location("indigo-plateau")

    assert_equal 5, plateau.trainers.size
    assert(plateau.trainers.all? { |t| t.marker_key.nil? })
    assert_equal [ "Lorelei", "Bruno", "Agatha", "Lance", "Blue" ], plateau.trainers.map(&:name)
  end

  test "a location with no trainers at all stays empty" do
    assert_empty location("route-1").trainers
  end

  test "gym trainers come from the gym floor and claim no letter" do
    gym = location("celadon-city").gym

    assert_equal 7, gym.trainers.size
    assert(gym.trainers.all? { |t| t.marker_key.nil? })
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

  test "the SS Anne counts the trainers in its cabins, which its own map never draws" do
    ship = location("ss-anne")

    assert_equal 17, ship.trainers.size
    assert_equal 16, ship.trainers.count { |t| t.marker_key.nil? }
  end

  test "a card ticks under the same key as its pin on the map" do
    route = location("route-3")
    card = route.trainers.first
    pin = route.area_maps.flat_map(&:markers).find { |m| m.ref == card.opp }

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
