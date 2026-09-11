require "test_helper"

class WalkthroughSyncsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "a guest has no save file to sync to" do
    post walkthrough_sync_path(game: "yellow"), params: batch, as: :json

    assert_response :unauthorized
  end

  test "a batch lands on the trainer's save file for that game" do
    sign_in users(:confirmed)

    post walkthrough_sync_path(game: "yellow"), params: batch, as: :json

    assert_response :success
    assert_equal({ "marks" => 1, "bodies" => 2, "done" => false }, response.parsed_body)
    assert_includes Progress::Snapshot.marks(save_files(:ash_yellow)), "route-3/item-11-9"
  end

  test "syncing a game the trainer has never opened starts the save file" do
    sign_in users(:rival)

    assert_difference("SaveFile.count", 1) do
      post walkthrough_sync_path(game: "yellow"), params: batch, as: :json
    end
  end

  test "the last batch is what marks the game taken up" do
    sign_in users(:confirmed)

    post walkthrough_sync_path(game: "yellow"), params: batch(final: true), as: :json

    assert_equal({ "marks" => 1, "bodies" => 2, "done" => true }, response.parsed_body)
    assert_not_nil save_files(:ash_yellow).reload.imported_at
    assert_not SaveFile.pending_import?(users(:confirmed), "yellow")
  end

  test "a batch that skips the counts still lands its marks" do
    sign_in users(:confirmed)

    post walkthrough_sync_path(game: "yellow"),
      params: { collected: { yellow: { "route-3/item-11-9" => true } } }, as: :json

    assert_equal({ "marks" => 1, "bodies" => 0, "done" => false }, response.parsed_body)
  end

  test "a batch carrying more keys than one write may hold is refused, not trimmed" do
    sign_in users(:confirmed)
    crowd = { yellow: (0..Progress::Sync::MAX_KEYS).to_h { |n| [ "route-3/item-#{n}", true ] } }

    assert_no_difference("WalkthroughMark.count") do
      post walkthrough_sync_path(game: "yellow"), params: batch(collected: crowd), as: :json
    end
    assert_response :unprocessable_content
  end

  test "too many counts in one batch is refused the same way" do
    sign_in users(:confirmed)
    crowd = { yellow: (0..Progress::Sync::MAX_KEYS).to_h { |n| [ format("%03d", n), 1 ] } }

    post walkthrough_sync_path(game: "yellow"), params: batch(bodies: crowd), as: :json

    assert_response :unprocessable_content
  end

  test "a game the picker does not offer is skipped rather than refused" do
    sign_in users(:confirmed)

    post walkthrough_sync_path(game: "yellow"),
      params: batch(collected: { crystal: { "route-3/item-11-9" => true },
                                 yellow: { "route-3/item-11-9" => true } }), as: :json

    assert_response :success
    assert_equal 1, response.parsed_body["marks"]
  end

  test "a malformed game is dropped, since a guest document is not a contract" do
    sign_in users(:confirmed)

    post walkthrough_sync_path(game: "yellow"),
      params: batch(collected: { yellow: "nope" }), as: :json

    assert_response :success
    assert_equal 0, response.parsed_body["marks"]
  end

  test "a game the guide has never heard of has nowhere to stamp" do
    sign_in users(:confirmed)

    post walkthrough_sync_path(game: "crystal"), params: batch(final: true), as: :json

    assert_response :not_found
  end

  test "sending the same batch twice changes nothing the second time" do
    sign_in users(:confirmed)
    post walkthrough_sync_path(game: "yellow"), params: batch, as: :json

    assert_no_difference([ "WalkthroughMark.count", "Pokemon.count" ]) do
      post walkthrough_sync_path(game: "yellow"), params: batch, as: :json
    end
  end

  private

  def batch(**overrides)
    { collected: { yellow: { "route-3/item-11-9" => true } },
      bodies: { yellow: { "010" => 2 } } }.merge(overrides)
  end
end
