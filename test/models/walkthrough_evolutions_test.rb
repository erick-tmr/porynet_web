require "test_helper"

class WalkthroughEvolutionsTest < ActiveSupport::TestCase
  def evolutions = game.evolutions

  def rules = Walkthrough::Evolutions

  def game = Walkthrough.find!("yellow")

  def legacy = Walkthrough.find!("yellow-legacy")

  test "the table carries every Gen 1 evolution, keyed by three-digit dex ids the names know" do
    assert_equal 72, evolutions.all.size

    evolutions.all.each do |evo|
      assert_match(/\A\d{3}\z/, evo.from)
      assert_match(/\A\d{3}\z/, evo.to)
      assert Walkthrough::Gen1Guide::NAMES.key?(evo.from), "unknown dex #{evo.from}"
      assert Walkthrough::Gen1Guide::NAMES.key?(evo.to), "unknown dex #{evo.to}"
    end
  end

  test "each row is a level, a stone or a trade, and carries the argument that kind needs" do
    by_kind = evolutions.all.group_by(&:kind).transform_values(&:size)

    assert_equal({ level: 52, stone: 16, trade: 4 }, by_kind)

    evolutions.all.each do |evo|
      assert_kind_of Integer, evo.arg if evo.level?
      assert_includes rules::STONE_SOURCES.keys, evo.arg if evo.stone?
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

    assert_equal 49, linear.size

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
    moon = evolutions.all.find { |evo| evo.to == "031" }

    assert_equal Walkthrough::Evolutions::MOON_STONE, moon.arg
    assert_equal "mt-moon", rules.stone_source(moon.arg)
    assert_equal "celadon-city", rules.stone_source(Walkthrough::Evolutions::LEAF_STONE)
  end

  test "Raichu cannot be evolved into: Yellow's starter Pikachu refuses the Thunder Stone" do
    assert rules.refused?("026")
    refute rules.refused?("031")
  end

  test "Raichu is in no encounter table either, so Yellow cannot produce one at all" do
    refute_includes game.obtainable_dex, "026"
    assert_empty game.locations.flat_map(&:encounters).select { |enc| enc.dex == "026" }
  end

  # Legacy drops the link cable: all four trade evolutions level up instead, which is what lets a
  # single cartridge finish the dex.
  test "Legacy levels up the four Pokemon vanilla can only evolve by trading" do
    levels = %w[065 068 076 094].to_h do |dex|
      [ Walkthrough::Gen1Guide::NAMES.fetch(dex), legacy.evolutions.into(dex).first ]
    end

    assert levels.values.all?(&:level?), "none of them still asks for a trade"
    assert_equal({ "Alakazam" => 42, "Machamp" => 38, "Golem" => 38, "Gengar" => 42 },
      levels.transform_values(&:arg))
    assert game.evolutions.into("065").first.trade?, "vanilla Yellow still needs the cable"
  end

  test "the two tables differ only in those four rows" do
    changed = legacy.evolutions.all - game.evolutions.all

    assert_equal 4, changed.size
    assert_equal %w[065 068 076 094], changed.map(&:to).sort
  end

  test "Legacy counts the traded stages as reachable, so the Oak challenge asks for them" do
    assert_includes legacy.obtainable_dex, "094"
    refute_includes game.obtainable_dex, "094", "vanilla cannot raise a Gengar on one cartridge"
  end
end
