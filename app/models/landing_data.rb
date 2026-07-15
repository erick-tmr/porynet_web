module LandingData
  Feature = Data.define(:num, :tag, :key)
  FEATURES = [
    Feature.new("01", "TRACKER", :tracker),
    Feature.new("02", "OAK", :oak),
    Feature.new("03", "GUIDES", :guides),
    Feature.new("04", "PARSER", :parser),
    Feature.new("05", "PORYPC", :porypc),
    Feature.new("06", "OFFLINE", :offline)
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

  DEX_LABELS = %w[016 019 010 013 129 021 041 074 092 063 066 096 027 043 056 054 039 052].freeze

  def self.hero_cells
    skips = [ 7, 13, 19 ]
    (0...48).map { |i| { filled: i < 22 && !skips.include?(i), cursor: i == 22 } }
  end

  def self.box_slots
    (0...30).map do |i|
      filled = i < 18
      { filled: filled, empty: !filled, dex: "#" + (DEX_LABELS[i] || "000") }
    end
  end
end
