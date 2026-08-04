require "test_helper"

class WalkthroughEvolutionsTest < ActiveSupport::TestCase
  def evolutions = Walkthrough::Evolutions

  def game = Walkthrough.find!("yellow")

  test "the table carries every Gen 1 evolution, keyed by three-digit dex ids the names know" do
    assert_equal 72, evolutions::ALL.size

    evolutions::ALL.each do |evo|
      assert_match(/\A\d{3}\z/, evo.from)
      assert_match(/\A\d{3}\z/, evo.to)
      assert Walkthrough::Yellow::NAMES.key?(evo.from), "unknown dex #{evo.from}"
      assert Walkthrough::Yellow::NAMES.key?(evo.to), "unknown dex #{evo.to}"
    end
  end

  test "each row is a level, a stone or a trade, and carries the argument that kind needs" do
    by_kind = evolutions::ALL.group_by(&:kind).transform_values(&:size)

    assert_equal({ level: 52, stone: 16, trade: 4 }, by_kind)

    evolutions::ALL.each do |evo|
      assert_kind_of Integer, evo.arg if evo.level?
      assert_includes evolutions::STONE_SOURCES.keys, evo.arg if evo.stone?
      assert_nil evo.arg if evo.trade?
    end
  end

  test "every step of every evolution line the walkthrough declares is a real evolution" do
    declared = game.locations.flat_map(&:encounters).map { |enc| enc.evo_line.map { |s| s[:dex] } }.uniq

    refute_empty declared

    declared.each do |chain|
      chain.each_cons(2) do |from, to|
        assert_includes evolutions.out_of(from).map(&:to), to,
          "the walkthrough claims #{from} evolves into #{to}, the game does not"
      end
    end
  end

  test "a declared line that does not branch is the table's whole chain, walked from either end" do
    linear = game.locations.flat_map(&:encounters)
      .map { |enc| enc.evo_line.map { |s| s[:dex] } }.uniq
      .select { |chain| chain.size > 1 }

    assert_equal 50, linear.size

    linear.each do |chain|
      assert_equal chain, evolutions.chain_for(chain.first),
        "the table disagrees with the declared #{chain.first} line"
      assert_equal chain, evolutions.chain_for(chain.last),
        "walking back from #{chain.last} must reach the same line"
    end
  end

  test "a species with no evolution is its own whole chain" do
    assert_equal %w[132], evolutions.chain_for("132")
    assert_empty evolutions.out_of("132")
    assert_empty evolutions.into("132")
  end

  test "Eevee branches into all three stones rather than picking one" do
    assert_equal %w[133 134 135 136], evolutions.chain_for("135")
    assert_equal %w[134 135 136], evolutions.out_of("133").map(&:to)
  end

  test "stone evolutions name the stop that first hands the stone over" do
    moon = evolutions::ALL.find { |evo| evo.to == "031" }

    assert_equal Walkthrough::Evolutions::MOON_STONE, moon.arg
    assert_equal "mt-moon", evolutions.stone_source(moon.arg)
    assert_equal "celadon-city", evolutions.stone_source(Walkthrough::Evolutions::LEAF_STONE)
  end

  test "Raichu cannot be evolved into: Yellow's starter Pikachu refuses the Thunder Stone" do
    assert evolutions.refused?("026")
    refute evolutions.refused?("031")
  end

  test "a refused evolution still leaves the species catchable, as Cerulean Cave proves" do
    raichu = game.locations.find { |loc| loc.slug == "cerulean-cave" }.encounters.find { |e| e.dex == "026" }

    assert_equal "4%", raichu.rate, "Raichu is off the evolution path, not out of the game"
    assert_includes game.obtainable_dex, "026"
  end
end
