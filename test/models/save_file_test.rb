require "test_helper"

class SaveFileTest < ActiveSupport::TestCase
  test "a save file belongs to one of the games the walkthrough index lists" do
    assert_predicate build(game_slug: "red"), :valid?
    assert_not build(game_slug: "crystal").valid?
    assert_not build(game_slug: nil).valid?
  end

  test "the games it offers are the ones the version picker offers" do
    assert_equal Walkthrough::Versions::CATALOGUE.map { |entry| entry[:slug] }, SaveFile::GAMES
  end

  test "a trainer keeps one save file per game" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      build(user: users(:confirmed), game_slug: "yellow").save!
    end
    assert_difference("SaveFile.count", 1) { build(user: users(:rival), game_slug: "yellow").save! }
  end

  test "opening a game hands back the save file already on it" do
    assert_equal save_files(:ash_yellow), SaveFile.for(users(:confirmed), "yellow")
  end

  test "opening a game nobody has played yet starts the save file" do
    started = assert_difference("SaveFile.count", 1) { SaveFile.for(users(:rival), "blue") }

    assert_equal "blue", started.game_slug
    assert_equal users(:rival), started.user
  end

  test "a game the guide has never heard of is not a save file to start" do
    assert_raises(ActiveRecord::RecordNotFound) { SaveFile.for(users(:rival), "crystal") }
  end

  test "closing a save file takes its marks and its Pokemon with it" do
    save = save_files(:ash_yellow)

    assert_difference("WalkthroughMark.count", -1) do
      assert_difference("Pokemon.count", -2) { save.destroy }
    end
  end

  test "a save file carries the name and id the trainer plays under" do
    save = save_files(:ash_yellow)
    save.update!(ot_name: "ASH", ot_id32: 12_345)

    assert_equal "ASH", save.reload.ot_name
    assert_equal 12_345, save.ot_id32
  end

  test "a save file started by a tick has no trainer name until the game says so" do
    assert_nil SaveFile.for(users(:rival), "blue").ot_name
  end

  test "a game whose guest progress has never been taken up is still pending" do
    assert SaveFile.pending_import?(users(:confirmed), "yellow"),
      "a save file with no import stamp has not taken up the browser's copy yet"
    assert SaveFile.pending_import?(users(:rival), "yellow"), "and neither has a game never opened"
  end

  test "a game the trainer has already synced is done asking" do
    save_files(:ash_yellow).update!(imported_at: Time.current)

    assert_not SaveFile.pending_import?(users(:confirmed), "yellow")
  end

  test "a game the picker does not offer is never pending" do
    assert_not SaveFile.pending_import?(users(:confirmed), "crystal")
  end

  private

  def build(**overrides)
    SaveFile.new({ user: users(:rival), game_slug: "yellow" }.merge(overrides))
  end
end
