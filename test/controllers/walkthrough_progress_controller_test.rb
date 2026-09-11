require "test_helper"

class WalkthroughProgressControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "a guest has no save file to write to" do
    patch walkthrough_progress_path(game: "yellow"), params: tick, as: :json

    assert_response :unauthorized
  end

  test "ticking a thing writes the mark the moment it is clicked" do
    sign_in users(:confirmed)

    patch walkthrough_progress_path(game: "yellow"), params: tick, as: :json

    assert_response :no_content
    assert_includes Progress::Snapshot.marks(save_files(:ash_yellow)), "route-3/item-11-9"
  end

  test "unticking clears the mark, which an import alone could never do" do
    sign_in users(:confirmed)
    gone = walkthrough_marks(:moon_stone).mark_id

    patch walkthrough_progress_path(game: "yellow"), params: { marks: { gone => false } }, as: :json

    assert_response :no_content
    assert_not_includes Progress::Snapshot.marks(save_files(:ash_yellow)), gone
  end

  test "a species is held at the count the page shows, not stepped by one" do
    sign_in users(:confirmed)

    patch walkthrough_progress_path(game: "yellow"), params: { bodies: { "025" => 4 } }, as: :json

    assert_equal 4, save_files(:ash_yellow).pokemon.of_species("025").count
  end

  test "releasing a species back to zero only ever reaches placeholders" do
    sign_in users(:confirmed)

    patch walkthrough_progress_path(game: "yellow"), params: { bodies: { "025" => 0 } }, as: :json

    assert_equal [ walkthrough_pokemon_nickname ],
      save_files(:ash_yellow).pokemon.of_species("025").pluck(:nickname)
  end

  test "the first tick on a game the trainer has never opened starts the save file" do
    sign_in users(:rival)

    assert_difference("SaveFile.count", 1) do
      patch walkthrough_progress_path(game: "yellow"), params: tick, as: :json
    end
  end

  test "an id that is not a mark is dropped rather than stored" do
    sign_in users(:confirmed)

    assert_no_difference("WalkthroughMark.count") do
      patch walkthrough_progress_path(game: "yellow"),
        params: { marks: { "not a mark" => true } }, as: :json
    end
    assert_response :no_content
  end

  test "more keys than one write may hold is refused, not trimmed" do
    sign_in users(:confirmed)
    crowd = (0..Progress::Sync::MAX_KEYS).to_h { |n| [ "route-3/item-#{n}", true ] }

    assert_no_difference("WalkthroughMark.count") do
      patch walkthrough_progress_path(game: "yellow"), params: { marks: crowd }, as: :json
    end
    assert_response :unprocessable_content
  end

  test "a game the guide has never heard of has nowhere to write to" do
    sign_in users(:confirmed)

    patch walkthrough_progress_path(game: "crystal"), params: tick, as: :json

    assert_response :not_found
  end

  test "the same tick twice lands on the same answer" do
    sign_in users(:confirmed)
    patch walkthrough_progress_path(game: "yellow"), params: tick, as: :json

    assert_no_difference("WalkthroughMark.count") do
      patch walkthrough_progress_path(game: "yellow"), params: tick, as: :json
    end
  end

  private

  def tick = { marks: { "route-3/item-11-9" => true } }

  def walkthrough_pokemon_nickname = pokemon(:named_pikachu).nickname
end
