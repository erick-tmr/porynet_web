require "test_helper"

class ProgressSnapshotTest < ActiveSupport::TestCase
  test "a save file reads back as the marks it holds, in a settled order" do
    save_file = save_files(:ash_yellow)
    Progress::Sync.apply(save_file, marks: { "route-3/item-11-9" => true })

    assert_equal [ "route-2/item-13-54", "route-3/item-11-9" ], Progress::Snapshot.marks(save_file)
  end

  test "a save file reads back as how many of each species it holds" do
    assert_equal({ "025" => 2 }, Progress::Snapshot.bodies(save_files(:ash_yellow)))
  end

  test "a save file nobody has touched reads back empty rather than missing" do
    fresh = SaveFile.for(users(:rival), "blue")

    assert_empty Progress::Snapshot.marks(fresh)
    assert_empty Progress::Snapshot.bodies(fresh)
  end
end
