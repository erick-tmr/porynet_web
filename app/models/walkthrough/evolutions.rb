module Walkthrough
  module Evolutions
    MOON_STONE = "Moon Stone".freeze
    FIRE_STONE = "Fire Stone".freeze
    WATER_STONE = "Water Stone".freeze
    THUNDER_STONE = "Thunder Stone".freeze
    LEAF_STONE = "Leaf Stone".freeze

    STONE_SOURCES = {
      MOON_STONE => "mt-moon",
      FIRE_STONE => "celadon-city",
      WATER_STONE => "celadon-city",
      THUNDER_STONE => "celadon-city",
      LEAF_STONE => "celadon-city"
    }.freeze

    REFUSED = %w[026].freeze

    ROWS = [
      [ "001", "002", :level, 16 ], [ "002", "003", :level, 32 ],
      [ "004", "005", :level, 16 ], [ "005", "006", :level, 36 ],
      [ "007", "008", :level, 16 ], [ "008", "009", :level, 36 ],
      [ "010", "011", :level, 7 ], [ "011", "012", :level, 10 ],
      [ "013", "014", :level, 7 ], [ "014", "015", :level, 10 ],
      [ "016", "017", :level, 18 ], [ "017", "018", :level, 36 ],
      [ "019", "020", :level, 20 ], [ "021", "022", :level, 20 ],
      [ "023", "024", :level, 22 ], [ "025", "026", :stone, THUNDER_STONE ],
      [ "027", "028", :level, 22 ], [ "029", "030", :level, 16 ],
      [ "030", "031", :stone, MOON_STONE ], [ "032", "033", :level, 16 ],
      [ "033", "034", :stone, MOON_STONE ], [ "035", "036", :stone, MOON_STONE ],
      [ "037", "038", :stone, FIRE_STONE ], [ "039", "040", :stone, MOON_STONE ],
      [ "041", "042", :level, 22 ], [ "043", "044", :level, 21 ],
      [ "044", "045", :stone, LEAF_STONE ], [ "046", "047", :level, 24 ],
      [ "048", "049", :level, 31 ], [ "050", "051", :level, 26 ],
      [ "052", "053", :level, 28 ], [ "054", "055", :level, 33 ],
      [ "056", "057", :level, 28 ], [ "058", "059", :stone, FIRE_STONE ],
      [ "060", "061", :level, 25 ], [ "061", "062", :stone, WATER_STONE ],
      [ "063", "064", :level, 16 ], [ "064", "065", :trade, nil ],
      [ "066", "067", :level, 28 ], [ "067", "068", :trade, nil ],
      [ "069", "070", :level, 21 ], [ "070", "071", :stone, LEAF_STONE ],
      [ "072", "073", :level, 30 ], [ "074", "075", :level, 25 ],
      [ "075", "076", :trade, nil ], [ "077", "078", :level, 40 ],
      [ "079", "080", :level, 37 ], [ "081", "082", :level, 30 ],
      [ "084", "085", :level, 31 ], [ "086", "087", :level, 34 ],
      [ "088", "089", :level, 38 ], [ "090", "091", :stone, WATER_STONE ],
      [ "092", "093", :level, 25 ], [ "093", "094", :trade, nil ],
      [ "096", "097", :level, 26 ], [ "098", "099", :level, 28 ],
      [ "100", "101", :level, 30 ], [ "102", "103", :stone, LEAF_STONE ],
      [ "104", "105", :level, 28 ], [ "109", "110", :level, 35 ],
      [ "111", "112", :level, 42 ], [ "116", "117", :level, 32 ],
      [ "118", "119", :level, 33 ], [ "120", "121", :stone, WATER_STONE ],
      [ "129", "130", :level, 20 ], [ "133", "134", :stone, WATER_STONE ],
      [ "133", "135", :stone, THUNDER_STONE ], [ "133", "136", :stone, FIRE_STONE ],
      [ "138", "139", :level, 40 ], [ "140", "141", :level, 40 ],
      [ "147", "148", :level, 30 ], [ "148", "149", :level, 55 ]
    ].freeze

    ALL = ROWS.map { |from, to, kind, arg| Evolution.new(from: from, to: to, kind: kind, arg: arg) }
      .freeze
    OUT_OF = ALL.group_by(&:from).freeze
    INTO = ALL.group_by(&:to).freeze

    def self.out_of(dex) = OUT_OF.fetch(dex, [])

    def self.into(dex) = INTO.fetch(dex, [])

    def self.refused?(dex) = REFUSED.include?(dex)

    def self.stone_source(stone) = STONE_SOURCES.fetch(stone)

    def self.root(dex)
      stage = dex
      stage = into(stage).first.from while into(stage).any?
      stage
    end

    def self.chain_for(dex)
      chain = [ root(dex) ]
      index = 0
      while index < chain.size
        chain.concat(out_of(chain[index]).map(&:to))
        index += 1
      end
      chain
    end
  end
end
