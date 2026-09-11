require "test_helper"

class PokemonContextTest < ActiveSupport::TestCase
  test "which game a Pokemon came from and which format it is written in are different questions" do
    assert_equal "gen1", Pokemon::Context.for("red")
    assert_equal "gen1", Pokemon::Context.for("blue")
    assert_equal "gen1", Pokemon::Context.for("yellow"),
      "three games, one format, which is why a gen 1 trade writes no new block"
  end

  test "every game the picker offers knows the format it writes" do
    SaveFile::GAMES.each { |slug| assert_includes Pokemon::Context::ALL, Pokemon::Context.for(slug) }
  end

  test "a game nobody has mapped is a mistake to notice, not a guess to make" do
    assert_raises(KeyError) { Pokemon::Context.for("gold") }
  end

  test "the one generation that shipped three formats keeps all three" do
    assert_includes Pokemon::Context::ALL, "gen8"
    assert_includes Pokemon::Context::ALL, "gen8a"
    assert_includes Pokemon::Context::ALL, "gen8b"
  end
end
