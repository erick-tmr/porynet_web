# Hardcoded demo content for the PORYNET landing page. Single source of truth,
# shared by the server-rendered view and the Stimulus controllers. Kept as a
# plain top-level module (not namespaced under the PorynetWeb app module) so it
# reads as page content rather than domain state.
module LandingData
  HERO_STATS = [ "GEN 1 & 2", "ALL 9 GENS SOON", "OPEN SOURCE", "SELF-HOSTED" ].freeze

  Feature = Data.define(:num, :tag, :title, :desc)
  FEATURES = [
    Feature.new("01", "TRACKER", "Collection tracker",
      "Every box, every ’mon. Flip between Living Dex (each specimen) and Oak mode (Pokédex registration) in one tap."),
    Feature.new("02", "OAK", "Oak Challenge",
      "Not a separate page — baked into the walkthrough. Each city shows what’s catchable and updates your dex as you play."),
    Feature.new("03", "GUIDES", "Guides & walkthroughs",
      "The best place and method to catch every Pokémon, plus exactly what’s available at each point of the game."),
    Feature.new("04", "PARSER", "Save-file parser",
      "Drop in your .sav and PORYNET reads your party and boxes, auto-cataloging your whole collection."),
    Feature.new("05", "POKéHOME", "Self-hosted PokéHome",
      "An open-source, self-hostable storage companion. Your Pokémon, your server, no cloud lock-in."),
    Feature.new("06", "SYNC", "Live sync",
      "Site and PokéHome stay in lockstep — catch, deposit or trade and it shows up everywhere instantly.")
  ].freeze

  City = Data.define(:name, :total, :oak, :dex, :new_mons)
  CITIES = [
    City.new("PALLET TOWN", 1, 1, 1, [ "Starter" ]),
    City.new("ROUTE 1", 3, 3, 5, [ "Pidgey", "Rattata" ]),
    City.new("VIRIDIAN FOREST", 9, 8, 14, [ "Caterpie", "Weedle", "Pikachu", "Metapod", "Kakuna" ]),
    City.new("PEWTER CITY", 12, 10, 18, [ "Nidoran♀", "Nidoran♂", "Spearow", "Sandshrew" ]),
    City.new("CERULEAN CITY", 22, 18, 34, [ "Abra", "Jigglypuff", "Mankey", "Bellsprout", "Oddish", "Meowth", "Psyduck" ]),
    City.new("VERMILION CITY", 31, 25, 48, [ "Diglett", "Growlithe", "Machop", "Magnemite", "Krabby", "Voltorb" ])
  ].freeze
  DEFAULT_CITY_INDEX = 3

  Gen = Data.define(:num, :region, :live)
  GENS = [
    Gen.new("1", "Kanto", true),
    Gen.new("2", "Johto", true),
    Gen.new("3", "Hoenn", false),
    Gen.new("4", "Sinnoh", false),
    Gen.new("5", "Unova", false),
    Gen.new("6", "Kalos", false),
    Gen.new("7", "Alola", false),
    Gen.new("8", "Galar", false),
    Gen.new("9", "Paldea", false)
  ].freeze

  FILTERS = [ "ALL", "MISSING", "SHINY ★", "BY TYPE", "IN PARTY" ].freeze

  DEX_LABELS = %w[016 019 010 013 129 021 041 074 092 063 066 096 027 043 056 054 039 052].freeze

  # 48-cell living-dex grid: first 22 filled, minus a few gaps, with a blinking
  # cursor on cell 22.
  def self.hero_cells
    skips = [ 7, 13, 19 ]
    (0...48).map { |i| { filled: i < 22 && !skips.include?(i), cursor: i == 22 } }
  end

  # 30-slot storage box: first 18 filled with dex numbers, rest empty.
  def self.box_slots
    (0...30).map do |i|
      filled = i < 18
      { filled: filled, empty: !filled, dex: "#" + (DEX_LABELS[i] || "000") }
    end
  end
end
