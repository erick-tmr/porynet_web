require "test_helper"

class PokemonTest < ActiveSupport::TestCase
  test "a Pokemon is a species the national dex numbers" do
    assert_predicate build(national_dex: "001"), :valid?
    assert_predicate build(national_dex: "151"), :valid?
    assert_not build(national_dex: "25").valid?
    assert_not build(national_dex: "abc").valid?
    assert_not build(national_dex: nil).valid?
  end

  test "a Pokemon's data is written in a format the app knows" do
    assert_predicate build(origin_context: "gen9a"), :valid?
    assert_not build(origin_context: "gen10").valid?
    assert_not build(origin_context: nil).valid?
  end

  test "every Pokemon gets a tracker that follows it wherever it goes" do
    caught = build.tap(&:save!)

    assert_not_nil caught.tracker
    assert_not_equal caught.tracker, build.tap(&:save!).tracker
  end

  test "a body ticked off the walkthrough is a placeholder until something fills it in" do
    assert_predicate pokemon(:spare_pikachu), :placeholder?
    assert_not_predicate pokemon(:named_pikachu), :placeholder?, "it has been named"

    blocked = build.tap(&:save!)
    blocked.blocks.create!(context: "gen1", payload: { level: 5 })

    assert_not_predicate blocked.reload, :placeholder?, "a save file filled it in"
  end

  test "the bodies of one species on a save file are the ones counted" do
    assert_equal 2, save_files(:ash_yellow).pokemon.of_species("025").count
    assert_empty save_files(:ash_yellow).pokemon.of_species("001")
  end

  test "the newest body is the first one a release reaches for" do
    oldest = pokemon(:spare_pikachu)
    newest = build.tap { |mon| mon.save!(touch: false) }

    assert_equal newest, save_files(:ash_yellow).pokemon.of_species("025").newest_first.first
    assert_includes save_files(:ash_yellow).pokemon.newest_first.to_a, oldest
  end

  private

  def build(**overrides)
    Pokemon.new({ save_file: save_files(:ash_yellow), national_dex: "025",
                  origin_context: "gen1", origin_game_slug: "yellow" }.merge(overrides))
  end
end
