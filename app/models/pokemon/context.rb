class Pokemon
  # Which format a Pokemon's data is written in, which is not the same question as which game it
  # came from. Red, Blue and Yellow are three games sharing one format, so a trade between them
  # writes no new block; generation 8 is the other way round, one generation holding three formats
  # that cannot read each other (Sword/Shield, Legends: Arceus, Brilliant Diamond).
  module Context
    ALL = %w[gen1 gen2 gen3 gen4 gen5 gen6 gen7 gen7b gen8 gen8a gen8b gen9 gen9a].freeze

    BY_GAME = { "yellow" => "gen1", "red" => "gen1", "blue" => "gen1",
                "green" => "gen1", "yellow-legacy" => "gen1" }.freeze

    def self.for(game_slug) = BY_GAME.fetch(game_slug)
  end
end
