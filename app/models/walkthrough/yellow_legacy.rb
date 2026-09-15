module Walkthrough
  # Pokémon Yellow Legacy, the TheSmithPlays romhack.
  #
  # It walks Kanto in the same order as the game it is built on, so it takes the same route
  # spine and the same stops from Gen1Guide; what differs is what is standing on them. Trainers
  # and the real per-floor spawn rates come from its own generated data and need nothing here.
  # What does need saying is the editorial half: which species a stop's page puts on a card, and
  # any item the hack moved. A stop whose cards the hack invalidates is overridden below; a stop
  # that is not here is the one the base game draws.
  module YellowLegacy
    K = "walkthrough.yellow_legacy".freeze
    DATA_PREFIX = "yellow_legacy".freeze
    SLUG = "yellow-legacy".freeze
    NAME = "Pokémon Yellow Legacy".freeze

    # Six trainer classes the hack adds. Janine takes over Fuchsia's gym, and Nurse Joy and
    # Officer Jenny stand where the anime would put them; the hack draws its own battle sprites
    # for those three. Weebra, Craig and Smith are the project's own people, and the game gives
    # them the overworld sprites named here rather than a class of their own.
    EXTRA_CLASS_LABELS = { "JOY" => "NURSE JOY", "JENNY" => "OFF. JENNY" }.freeze

    EXTRA_CLASS_SPRITES = {
      "JANINE" => "janine-gen2", "NURSE JOY" => "nurse-gen2", "OFF. JENNY" => "officer-gen2",
      "WEEBRA" => "kris-gen2", "CRAIG" => "red-gen1", "SMITH" => "red-gen1"
    }.freeze

    extend Gen1Guide

    # Route 4's ball holds Razor Wind here: Whirlwind is gone from the game, its TM slot given
    # over to Flamethrower. Everything else about the stop, its grass included, is reconciled
    # from the table below.
    def self.route_4
      loc("route-4", "ROUTE", "Route 4", 10,
        steps: [
          { scene: "route-4-exit", pins: { exit: "route-4/exit-24-5" } },
          { hidden: [ "Great Ball", "great-ball", "route-4-hidden-great-ball", "route-4-great-ball" ] },
          { item: [ "TM Razor Wind", "tm-razor-wind" ], scene: "route-4-item-tm-razor-wind" },
          { pins: { east: "route-4/exit-east" } }
        ])
    end

    # Every stop's wild cards are rebuilt from this game's own tables. The hack moves spawns at
    # nearly every stop in Kanto, so an authored list written for the base game is wrong far
    # more often than it is right, and a card naming a species that no longer lives here is
    # worse than no card at all.
    def self.all_locations = super.map { |loc| reconcile_encounters(loc) }
  end
end
