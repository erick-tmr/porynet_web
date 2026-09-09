require "test_helper"

class ProgressImportTest < ActiveSupport::TestCase
  def guest(**overrides)
    { "v" => 2,
      "collected" => { "yellow" => { "route-3/item-11-9" => true } },
      "bodies" => { "yellow" => { "010" => 2 } } }.merge(overrides)
  end

  test "a guest's progress lands on the save file for the game it belongs to" do
    landed = Progress::Import.call(users(:rival), guest)

    save_file = SaveFile.find_by!(user: users(:rival), game_slug: "yellow")

    assert_equal 1, landed["yellow"].marks
    assert_equal 2, landed["yellow"].bodies
    assert_equal [ "route-3/item-11-9" ], Progress::Snapshot.marks(save_file)
    assert_equal({ "010" => 2 }, Progress::Snapshot.bodies(save_file))
  end

  test "importing starts the save file for a game the trainer has never opened" do
    assert_difference("SaveFile.count", 1) { Progress::Import.call(users(:rival), guest) }
  end

  test "importing adds to what is already there and never takes anything away" do
    Progress::Import.call(users(:confirmed), guest)
    save_file = save_files(:ash_yellow)

    assert_includes Progress::Snapshot.marks(save_file), walkthrough_marks(:moon_stone).mark_id
    assert_includes Progress::Snapshot.marks(save_file), "route-3/item-11-9"
    assert_equal({ "010" => 2, "025" => 2 }, Progress::Snapshot.bodies(save_file))
  end

  test "a count already beaten on the save file is left where it is" do
    Progress::Import.call(users(:confirmed), guest("bodies" => { "yellow" => { "025" => 1 } }))

    assert_equal 2, save_files(:ash_yellow).pokemon.of_species("025").count,
      "an import raises a count, it never lowers one"
  end

  test "importing the same progress twice changes nothing the second time" do
    Progress::Import.call(users(:rival), guest)

    assert_no_difference([ "WalkthroughMark.count", "Pokemon.count" ]) do
      Progress::Import.call(users(:rival), guest)
    end
  end

  test "a game the picker does not offer is skipped rather than refused" do
    landed = Progress::Import.call(users(:rival), guest("collected" => {
      "crystal" => { "route-3/item-11-9" => true }, "yellow" => { "route-3/item-11-9" => true }
    }))

    assert_equal %w[yellow], landed.keys
  end

  test "an id that is not a mark is dropped, and the rest of the blob still lands" do
    landed = Progress::Import.call(users(:rival), guest("collected" => { "yellow" => {
      "route-3/item-11-9" => true, "not a mark" => true, "025" => true, "a/#{'b' * 96}" => true
    } }))

    assert_equal 1, landed["yellow"].marks
  end

  test "a mark the guest unticked before signing up does not arrive ticked" do
    landed = Progress::Import.call(users(:rival), guest("collected" => {
      "yellow" => { "route-3/item-11-9" => false }
    }))

    assert_equal 0, landed["yellow"].marks
  end

  test "a species that is not a species is dropped" do
    landed = Progress::Import.call(users(:rival), guest("bodies" => {
      "yellow" => { "010" => 1, "10" => 5, "abc" => 5 }
    }))

    assert_equal 1, landed["yellow"].bodies
  end

  test "an empty document lands nothing and starts no save file" do
    assert_no_difference("SaveFile.count") { assert_empty Progress::Import.call(users(:rival), {}) }
  end
end
