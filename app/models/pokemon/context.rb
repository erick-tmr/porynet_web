class Pokemon
  module Context
    ALL = %w[gen1 gen2 gen3 gen4 gen5 gen6 gen7 gen7b gen8 gen8a gen8b gen9 gen9a].freeze

    BY_GAME = { "yellow" => "gen1", "red" => "gen1", "blue" => "gen1",
                "green" => "gen1", "yellow-legacy" => "gen1" }.freeze

    def self.for(game_slug) = BY_GAME.fetch(game_slug)
  end
end
