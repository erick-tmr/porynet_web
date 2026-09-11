require "test_helper"

class WalkthroughMarkTest < ActiveSupport::TestCase
  test "a mark names a place and the thing on it" do
    assert_predicate build(mark_id: "route-2/hidden-13-45"), :valid?
    assert_predicate build(mark_id: "indigo-plateau/trainer-lorelei"), :valid?
    assert_not build(mark_id: "route-2").valid?, "a place with nothing on it marks nothing"
    assert_not build(mark_id: "025").valid?, "a species is a Pokemon, not a mark"
    assert_not build(mark_id: "Route-2/Item").valid?
    assert_not build(mark_id: "route-2/item 13").valid?
    assert_not build(mark_id: nil).valid?
  end

  test "a mark is refused before it can outgrow its column" do
    assert_not build(mark_id: "a/#{'b' * 96}").valid?
  end

  test "the same thing is only marked once on a save file" do
    again = build(mark_id: walkthrough_marks(:moon_stone).mark_id)

    assert_not again.valid?
    assert_includes again.errors[:mark_id], "has already been taken"
  end

  test "two save files mark the same thing without seeing each other" do
    other = SaveFile.create!(user: users(:rival), game_slug: "yellow")

    assert_predicate build(save_file: other, mark_id: walkthrough_marks(:moon_stone).mark_id), :valid?
  end

  private

  def build(**overrides)
    WalkthroughMark.new({ save_file: save_files(:ash_yellow), mark_id: "route-3/item-11-9" }.merge(overrides))
  end
end
