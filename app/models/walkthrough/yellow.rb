module Walkthrough
  # Pokémon Yellow, the guide the engine was written against.
  #
  # Everything that draws a page lives in Gen1Guide; what is here is what makes this game this
  # game: where its copy is, which generated data it reads, and what it is called.
  module Yellow
    K = "walkthrough.yellow".freeze
    DATA_PREFIX = "yellow".freeze
    SLUG = "yellow".freeze
    NAME = "Pokémon Yellow".freeze
    EXTRA_CLASS_LABELS = {}.freeze
    EXTRA_CLASS_SPRITES = {}.freeze

    extend Gen1Guide
  end
end
