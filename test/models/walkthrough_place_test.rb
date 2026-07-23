require "test_helper"

class WalkthroughPlaceTest < ActiveSupport::TestCase
  def game = Walkthrough.find!("yellow")

  def place(**overrides) = Walkthrough::Place.new(**{ kind: "house" }.merge(overrides))

  def hint(**overrides) = Walkthrough::PlaceHint.new(place(**overrides)).to_s

  def gift(name, dex, level, sold: false)
    Walkthrough::Gift.new(dex: dex, name: name, level: level, sold: sold)
  end

  def exit_marker(name)
    game.locations.flat_map(&:area_maps).flat_map(&:markers).find { |marker| marker.name == name }
  end

  test "place facts are parsed once and handed back frozen" do
    first = Walkthrough::Yellow.place_facts

    assert_same first, Walkthrough::Yellow.place_facts
    assert_predicate first, :frozen?
  end

  test "an exit carries the facts the game states about the map behind the door" do
    lab = exit_marker("Oaks Lab").place

    assert_predicate exit_marker("Oaks Lab"), :place?
    assert_equal "lab", lab.kind
    assert_equal [ "Poké Ball" ], lab.gift_item.map(&:name)
    assert_equal 5, lab.gift_item.first.qty
    assert_equal 1, lab.trainers
  end

  test "only exits carry a place, so an item marker keeps its own hint" do
    potion = game.locations.flat_map(&:area_maps).flat_map(&:markers).find { |m| m.cat == "item" }

    refute_predicate potion, :place?
  end

  test "a curated note leads the hint where the game data has nothing to say" do
    nickname = exit_marker("Viridian Nickname House").place

    assert_predicate nickname, :note?
    assert_equal I18n.t("walkthrough.ui.map_place_note_viridian_nickname"),
      Walkthrough::PlaceHint.new(nickname).to_s
  end

  test "the note clears up which nickname house actually renames a Pokémon" do
    assert_match(/Name Rater in Lavender Town/,
      Walkthrough::PlaceHint.new(exit_marker("Viridian Nickname House").place).to_s)
    assert_match(/give it a new nickname/,
      Walkthrough::PlaceHint.new(exit_marker("Name Raters House").place).to_s)
  end

  test "the vague school house now reads as a trainer's school" do
    assert_equal I18n.t("walkthrough.ui.map_place_note_viridian_school"),
      Walkthrough::PlaceHint.new(exit_marker("Viridian School House").place).to_s
  end

  test "every note in the overlay lands on a real place and has copy in both locales" do
    overlay = JSON.parse(File.read(Rails.root.join("app/models/walkthrough/yellow_place_notes.json")))
    noted = Walkthrough::Yellow.place_facts.values.select(&:note?).map(&:note).uniq

    assert_equal overlay.values.uniq.sort, noted.sort,
      "a note key is set on a map const that is not a known place (a typo in the overlay)"
    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        noted.each { |key| assert_not_empty I18n.t("walkthrough.ui.#{key}") }
      end
    end
  end

  test "a note leads but the mechanical facts still trail it" do
    noted = place(kind: "house", note: "map_place_note_name_rater", items: 1)

    assert_equal "#{I18n.t('walkthrough.ui.map_place_note_name_rater')} " \
                 "#{I18n.t('walkthrough.ui.map_place_items', count: 1)}",
      Walkthrough::PlaceHint.new(noted).to_s
  end

  test "a gym hint names the leader, the team, the badge and the TM" do
    assert_equal "Erika's Gym, a Grass team. Win the Rainbow Badge and TM21 Mega Drain. " \
                 "7 trainers inside.",
      Walkthrough::PlaceHint.new(exit_marker("Celadon Gym").place).to_s
  end

  test "a gym whose party shares two types names both" do
    assert_includes Walkthrough::PlaceHint.new(exit_marker("Pewter Gym").place).to_s,
      "a Rock/Ground team"
  end

  test "a mart hint lists its stock and counts the rest away" do
    assert_equal "Poké Mart. Sells Poké Ball, Potion, Antidote, Parlyz Heal.",
      hint(kind: "mart", stock: [ "Poké Ball", "Potion", "Antidote", "Parlyz Heal" ])
    assert_equal "Poké Mart. Sells Poké Ball, Potion, Antidote, Parlyz Heal and 2 more.",
      hint(kind: "mart", stock: [ "Poké Ball", "Potion", "Antidote", "Parlyz Heal", "Repel", "Revive" ])
  end

  test "a counter inside something that is not a mart trails the sentence naming the place" do
    assert_equal "A Pokémon League room. No turning back once you enter. Sells Ultra Ball.",
      hint(kind: "league", stock: [ "Ultra Ball" ])
  end

  test "a free Pokémon is called out, and one you have to pay for is not called free" do
    assert_equal "A house. Walk in and talk to whoever lives there. " \
                 "A free Eevee at Lv 25 waits inside.",
      hint(gift_mon: [ gift("Eevee", "133", 25) ])
    assert_equal "Pokémon Center. Free healing, and the PC for your boxes. " \
                 "Someone in here sells a Magikarp at Lv 5.",
      hint(kind: "center", gift_mon: [ gift("Magikarp", "129", 5, sold: true) ])
  end

  test "two gift Pokémon on one map are the pick the game offers, not two prizes" do
    assert_equal "A dojo. Its fighters hand a Pokémon to whoever beats them. " \
                 "Your pick of a free Hitmonlee or Hitmonchan, both at Lv 30.",
      hint(kind: "dojo", gift_mon: [ gift("Hitmonlee", "106", 30), gift("Hitmonchan", "107", 30) ])
  end

  test "handed-over items are listed, and a stack says how many" do
    assert_equal "A house. Walk in and talk to whoever lives there. " \
                 "Someone inside hands out: Town Map, 5× Poké Ball.",
      hint(gift_item: [ Walkthrough::GiftItem.new(name: "Town Map", qty: 1),
                        Walkthrough::GiftItem.new(name: "Poké Ball", qty: 5) ])
  end

  test "trainers and item balls are counted only when the map has any" do
    assert_equal "An indoor route. Wild Pokémon live in here. 1 trainer inside. 2 item balls inside.",
      hint(kind: "dungeon", trainers: 1, items: 2)
    assert_equal "An indoor route. Wild Pokémon live in here.", hint(kind: "dungeon")
  end

  test "every kind the generator emits has copy in both locales" do
    kinds = Walkthrough::Yellow.place_facts.values.map(&:kind).uniq

    Walkthrough::Yellow.place_facts.each_value do |facts|
      assert_not_empty Walkthrough::PlaceHint.new(facts).to_s
    end
    I18n.with_locale(:pt) do
      kinds.each { |kind| assert_not_empty I18n.t("walkthrough.ui.map_place_kind_#{kind}") }
    end
  end
end
