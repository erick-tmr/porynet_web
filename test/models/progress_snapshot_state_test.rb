require "test_helper"

class ProgressSnapshotStateTest < ActiveSupport::TestCase
  test "a save file reads back in the shape the walkthrough renders from" do
    state = Progress::Snapshot.state(save_files(:ash_yellow), "yellow")

    assert_equal({ walkthrough_marks(:moon_stone).mark_id => true }, state[:collected]["yellow"])
    assert_equal({ "025" => 2 }, state[:bodies]["yellow"])
  end

  test "a species is caught because the save file holds one, which no column records" do
    state = Progress::Snapshot.state(save_files(:ash_yellow), "yellow")

    assert_equal({ "025" => true }, state[:caught]["yellow"],
      "caught is derived from bodies on the way down, since backfill only goes the other way")
  end

  test "a game the trainer has never opened reads back empty rather than missing" do
    state = Progress::Snapshot.state(nil, "yellow")

    assert_equal({ collected: { "yellow" => {} }, caught: { "yellow" => {} },
                   bodies: { "yellow" => {} } }, state)
  end
end
