module Walkthrough
  module YellowLegacy
    K = "walkthrough.yellow_legacy".freeze
    DATA_PREFIX = "yellow_legacy".freeze
    SLUG = "yellow-legacy".freeze
    NAME = "Pokémon Yellow Legacy".freeze

    EXTRA_CLASS_LABELS = { "JOY" => "NURSE JOY", "JENNY" => "OFF. JENNY" }.freeze

    EXTRA_CLASS_SPRITES = {
      "JANINE" => "janine-gen2", "NURSE JOY" => "nurse-gen2", "OFF. JENNY" => "officer-gen2",
      "WEEBRA" => "kris-gen2", "CRAIG" => "red-gen1", "SMITH" => "red-gen1"
    }.freeze

    extend Gen1Guide

    def self.route_4
      loc("route-4", "ROUTE", "Route 4", 10,
        steps: [
          { scene: "route-4-exit", pins: { exit: "route-4/exit-24-5" } },
          { hidden: [ "Great Ball", "great-ball", "route-4-hidden-great-ball", "route-4-great-ball" ] },
          { item: [ "TM Razor Wind", "tm-razor-wind" ], scene: "route-4-item-tm-razor-wind" },
          { pins: { east: "route-4/exit-east" } }
        ])
    end

    def self.all_locations = super.map { |loc| reconcile_encounters(loc) }
  end
end
