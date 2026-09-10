require "test_helper"

class ProgressImportTest < ActiveSupport::TestCase
  def save_file = save_files(:ash_yellow)

  def batch(**overrides)
    Progress::Import.batch(save_file, **{ collected: { "route-3/item-11-9" => true },
                                          bodies: { "010" => 2 } }.merge(overrides))
  end

  test "a batch lands on the save file it is handed" do
    landed = batch

    assert_equal 1, landed.marks
    assert_equal 2, landed.bodies
    assert_includes Progress::Snapshot.marks(save_file), "route-3/item-11-9"
  end

  test "a batch adds to what is already there and never takes anything away" do
    batch

    assert_includes Progress::Snapshot.marks(save_file), walkthrough_marks(:moon_stone).mark_id
    assert_equal({ "010" => 2, "025" => 2 }, Progress::Snapshot.bodies(save_file))
  end

  test "a count already beaten on the save file is left where it is" do
    landed = batch(bodies: { "025" => 1 })

    assert_equal 0, landed.bodies
    assert_equal 2, save_file.pokemon.of_species("025").count,
      "an import raises a count, it never lowers one"
  end

  test "sending the same batch twice changes nothing the second time" do
    batch

    assert_no_difference([ "WalkthroughMark.count", "Pokemon.count" ]) { batch }
  end

  test "an id that is not a mark is dropped, and the rest of the batch still lands" do
    landed = batch(collected: { "route-3/item-11-9" => true, "not a mark" => true,
                                "025" => true, "a/#{'b' * 96}" => true })

    assert_equal 1, landed.marks
  end

  test "a mark the guest unticked before signing up does not arrive ticked" do
    assert_equal 0, batch(collected: { "route-3/item-11-9" => false }).marks
  end

  test "a species that is not a species is dropped" do
    assert_equal 1, batch(bodies: { "010" => 1, "10" => 5, "abc" => 5 }).bodies
  end

  test "an empty batch lands nothing" do
    landed = assert_no_difference([ "WalkthroughMark.count", "Pokemon.count" ]) do
      Progress::Import.batch(save_file)
    end

    assert_equal 0, landed.marks
    assert_equal 0, landed.bodies
  end
end
