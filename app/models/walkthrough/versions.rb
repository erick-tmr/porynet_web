module Walkthrough
  module Versions
    Entry = Data.define(:slug, :name, :cover, :fit, :released, :tone, :pages) do
      def live? = pages.positive?
      def dated? = released.any?
    end

    CATALOGUE = [
      { slug: "yellow", name: "Pokémon Yellow", cover: "yellow", fit: "contain",
        released: [ "JP 1998", "INTL 1999" ], tone: "paper" },
      { slug: "red", name: "Pokémon Red", cover: "red", fit: "contain",
        released: [ "JP 1996", "INTL 1998" ], tone: "paper" },
      { slug: "blue", name: "Pokémon Blue", cover: "blue", fit: "contain",
        released: [ "JP 1996", "INTL 1998" ], tone: "paper" },
      { slug: "green", name: "Pokémon Green", cover: "green-jp", fit: "crop",
        released: [ "JP 1996" ], tone: "paper" },
      { slug: "yellow-legacy", name: "Pokémon Yellow Legacy", cover: "yellow-legacy",
        fit: "contain", released: [], tone: "dark" }
    ].freeze

    MARQUEE = [ "RED", "GREEN", "BLUE", "YELLOW", "YELLOW LEGACY" ].freeze

    def self.all
      pages = Walkthrough.games.transform_values { |game| game.legs.size }
      CATALOGUE.map { |entry| Entry.new(**entry, pages: pages.fetch(entry[:slug], 0)) }
    end
  end
end
