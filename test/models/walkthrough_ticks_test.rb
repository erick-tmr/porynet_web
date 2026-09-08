require "test_helper"

# Every tick id is a durable key: it is what a player's saved progress points at, so a content
# edit that moves one silently re-points somebody's collection. These are the rules that keep
# them stable, and they are checked over the whole game rather than over a sample.
class WalkthroughTicksTest < ActiveSupport::TestCase
  GRAMMAR = %r{\A[a-z0-9][a-z0-9-]*/[a-z0-9][a-z0-9-]*\z}

  def game = Walkthrough.find!("yellow")

  # [kind, tick] for everything on a stop's page a player can tick off. Kind matters because the
  # same id is shared on purpose across kinds and pages (a come-back-later card and the step that
  # finally collects it are one item seen twice); two of the same kind at one stop are not.
  def tickables(loc)
    rows = loc.steps.flat_map { |step| step.items.map { |i| [ :item, i ] } + step.hidden.map { |h| [ :hidden, h ] } }
    rows += loc.later.map { |l| [ :later, l ] }
    rows += loc.trainers.map { |t| [ :trainer, t ] }
    rows += loc.trades.map { |t| [ :trade, t ] }
    rows + [ loc.gym, loc.dojo ].compact.flat_map do |hall|
      hall.trainers.map { |t| [ :hall, t ] } << [ :hall, hall.leader ]
    end
  end

  def all_tickables = game.locations.flat_map { |loc| tickables(loc) }

  test "everything a player can tick off carries an id" do
    missing = all_tickables.select { |_kind, thing| thing.tick.blank? }

    assert_empty missing.map { |kind, thing| "#{kind} #{thing.inspect}" },
      "a card with no id renders a tick target nobody can save"
  end

  test "no two things of one kind at one stop answer to the same id" do
    clashes = game.locations.flat_map do |loc|
      tickables(loc).group_by { |kind, thing| [ kind, thing.tick ] }
        .select { |_key, rows| rows.size > 1 }
        .map { |(kind, tick), _rows| "#{loc.slug} #{kind} #{tick}" }
    end

    assert_empty clashes, "two cards sharing one id tick each other off"
  end

  test "every id is a stop or a map, then the thing on it" do
    game.locations.each do |loc|
      tickables(loc).each do |kind, thing|
        assert_match GRAMMAR, thing.tick, "#{loc.slug} #{kind}"
      end
    end
  end

  # The four shapes an id comes in. A pin-derived one ends in the grid cell the marker sits on and
  # comes from the map data; the rest are authored, and read as what they are.
  test "an id says where the thing is and what it is" do
    assert_equal "route-2/item-13-54", loc("route-2").later.first.tick
    assert_equal "viridian-city/item-oaks-parcel",
      loc("viridian-city").steps.flat_map(&:items).find { |i| i.name == "Oak's Parcel" }.tick
    assert_equal "pallet-town/trainer-blue", loc("pallet-town").trainers.sole.tick
    assert_equal "cinnabar-island/trade-muk", loc("cinnabar-island").trades.first.tick
  end

  test "a species ticks under its dex number, wherever the guide draws it" do
    dexes = game.locations.flat_map { |loc| loc.encounters.map(&:dex) }.uniq

    assert_equal 105, dexes.size
    dexes.each { |dex| assert_match(/\A\d{3}\z/, dex) }
  end

  private

  def loc(slug) = game.locations.find { |l| l.slug == slug }
end
