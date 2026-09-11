require "test_helper"

class ProgressSyncTest < ActiveSupport::TestCase
  def save_file = save_files(:ash_yellow)

  test "marking something writes one row, and marking it again writes nothing" do
    assert_difference("WalkthroughMark.count", 1) { apply(marks: { "route-3/item-11-9" => true }) }
    assert_no_difference("WalkthroughMark.count") { apply(marks: { "route-3/item-11-9" => true }) }
  end

  test "unmarking deletes the row, and unmarking nothing is not an error" do
    assert_difference("WalkthroughMark.count", -1) do
      apply(marks: { walkthrough_marks(:moon_stone).mark_id => false })
    end
    assert_no_difference("WalkthroughMark.count") { apply(marks: { "route-3/item-11-9" => false }) }
  end

  test "the count asked for is the count held, however many times it is asked for" do
    assert_equal({ "010" => 3 }, apply(bodies: { "010" => 3 }))
    assert_equal({ "010" => 3 }, apply(bodies: { "010" => 3 }))
    assert_equal 3, save_file.pokemon.of_species("010").count
  end

  test "asking for fewer releases the bodies most recently caught" do
    apply(bodies: { "010" => 3 })
    keep = save_file.pokemon.of_species("010").newest_first.last

    assert_equal({ "010" => 1 }, apply(bodies: { "010" => 1 }))
    assert_equal [ keep ], save_file.pokemon.of_species("010").to_a
  end

  test "asking for none releases them all" do
    apply(bodies: { "010" => 2 })

    assert_equal({ "010" => 0 }, apply(bodies: { "010" => 0 }))
    assert_empty save_file.pokemon.of_species("010")
  end

  test "a release stops at a Pokemon a save file has filled in" do
    assert_equal({ "025" => 1 }, apply(bodies: { "025" => 0 }),
      "the nicknamed one is not a body the walkthrough may throw away")
    assert_equal [ pokemon(:named_pikachu) ], save_file.pokemon.of_species("025").to_a
  end

  test "nobody can ask for more bodies than a box could hold" do
    assert_equal({ "010" => Progress::Sync::MAX_BODIES }, apply(bodies: { "010" => 10_000 }))
  end

  test "marking a trade hands over the Pokemon it trades for, named and signed" do
    assert_difference("Pokemon.count", 1) { apply(marks: { "route-2/trade-mr-mime" => true }) }

    miles = save_file.pokemon.of_species("122").sole

    assert_equal "MILES", miles.nickname
    assert_equal "TRAINER", miles.ot_name
    assert_equal "gen1", miles.origin_context
    assert_predicate miles, :traded?
  end

  test "marking a trade twice does not hand over two of them" do
    apply(marks: { "route-2/trade-mr-mime" => true })

    assert_no_difference("Pokemon.count") { apply(marks: { "route-2/trade-mr-mime" => true }) }
  end

  test "unmarking a trade takes back the Pokemon it handed over" do
    apply(marks: { "route-2/trade-mr-mime" => true })

    assert_difference("Pokemon.count", -1) { apply(marks: { "route-2/trade-mr-mime" => false }) }
  end

  test "unmarking anything else leaves the collection alone" do
    apply(marks: { "route-3/item-11-9" => true })

    assert_no_difference("Pokemon.count") { apply(marks: { "route-3/item-11-9" => false }) }
  end

  test "one request cannot ask for more keys than it is allowed" do
    wanted = (1..70).to_h { |n| [ "route-3/item-#{n}", true ] }

    assert_difference("WalkthroughMark.count", Progress::Sync::MAX_KEYS) { apply(marks: wanted) }
  end


  test "an id it cannot store is dropped rather than written" do
    assert_no_difference("WalkthroughMark.count") do
      apply(marks: { "not a mark" => true, "025" => true })
    end
  end

  test "a species that is not a species is dropped too" do
    assert_no_difference("Pokemon.count") { apply(bodies: { "abc" => 3, "10" => 3 }) }
  end

  private

  def apply(**args) = Progress::Sync.apply(save_file, **args)
end
