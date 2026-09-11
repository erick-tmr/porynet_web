require "test_helper"

class PokemonBlockTest < ActiveSupport::TestCase
  test "a block is written in one of the formats the series has shipped" do
    assert_predicate build(context: "gen1"), :valid?
    assert_predicate build(context: "gen8b"), :valid?
    assert_not build(context: "gen1b").valid?
    assert_not build(context: nil).valid?
  end

  test "a Pokemon holds one block per format, not two" do
    again = build(pokemon: pokemon(:named_pikachu), context: "gen1")

    assert_not again.valid?
    assert_includes again.errors[:context], "has already been taken"
    assert_predicate build(pokemon: pokemon(:named_pikachu), context: "gen7"), :valid?
  end

  test "a block keeps the fields its own format has and nothing it does not" do
    gen1 = pokemon_blocks(:sparky_gen1)

    assert_equal 43_690, gen1.payload["dv16"], "four DVs packed into one word, never unpacked here"
    assert_equal "ELECTRIC", gen1.payload["type1"]
    assert_nil gen1.payload["nature"], "generation 1 has no nature to record"
    assert_nil gen1.payload["ot_name"],
      "who caught it is true in every generation, so it is a column rather than a block field"
  end

  test "a fresh block starts empty rather than nil" do
    assert_empty build.tap(&:save!).payload
  end

  private

  def build(**overrides)
    PokemonBlock.new({ pokemon: pokemon(:spare_pikachu), context: "gen1" }.merge(overrides))
  end
end
