class PokemonBlock < ApplicationRecord
  belongs_to :pokemon

  validates :context, inclusion: { in: Pokemon::Context::ALL },
                      uniqueness: { scope: :pokemon_id }
end
