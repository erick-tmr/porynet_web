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

    METHOD_UNLOCK = {
      "OLD ROD" => 3,      # Viridian City, the Fishing Guru inside the Mart
      "GOOD ROD" => 17,    # Vermilion City, the Guru's older brother
      "SUPER ROD" => 31,   # Route 12, the Super Rod house
      "SURF" => 36         # Safari Zone, HM03 in the Secret House
    }.freeze

    VIRIDIAN_STEPS = [
      { item: [ "Oak's Parcel", "oaks_parcel" ], scene: "viridian-mart-parcel",
        pins: { center: "viridian-city/exit-23-25", mart: "viridian-city/exit-29-19" } },
      { item: [ "Pokédex", "pokedex" ] },
      { item: [ "Town Map", "town_map" ], scene: "blues-house-town-map" },
      {},
      { item: [ "Old Rod", "old_rod" ], scene: "viridian-mart-old-rod",
        pins: { mart: "viridian-city/exit-29-19" } },
      {},
      { hidden: [ "Potion", "potion", "viridian-city-hidden-potion", "viridian-city-potion" ],
        pins: { north: "viridian-city/exit-north" } },
      { pins: { gym: "viridian-city/exit-32-7", west: "viridian-city/exit-west" } }
    ].freeze

    extend Gen1Guide

    def self.method_unlock = METHOD_UNLOCK

    def self.evolutions = Evolutions::LEGACY

    CHANGED_ANCHOR = "what-changed".freeze

    def self.changed_anchor(slug) = "#{slug}-#{CHANGED_ANCHOR}"

    # One section per stop whose bystanders brief you on a rule. A "yes" mark is something Legacy
    # altered, a "na" mark a Gen 1 rule the original never spelled out, and the section's own note
    # says which is which. `pins` name the markers the sentence points at.
    WHAT_CHANGED = {
      "pallet-town" => {
        facts: { "running" => "yes", "bag" => "yes", "pikachu" => "yes", "ghost" => "yes",
                 "bug" => "no" },
        pins: { shoes: "pallet-town/npc-running-shoes", bag: "pallet-town/npc-bigger-bag",
                lab: "pallet-town/exit-12-11" },
        shot: "pallet-running-shoes"
      },
      "route-1" => {
        facts: { "stat_exp" => "na" },
        pins: { youngster: "route-1/npc-stat-exp" }
      },
      "viridian-city" => {
        facts: { "dvs" => "yes", "habitats" => "yes", "trade_evos" => "yes", "rods" => "yes",
                 "enemy_pp" => "na" },
        pins: { dvs: "viridian-city/npc-dvs", habitats: "viridian-city/npc-habitats",
                school: "viridian-city/exit-21-15", mart: "viridian-city/exit-29-19" },
        shot: "viridian-dvs"
      },
      "route-3" => {
        facts: { "box_call" => "yes" },
        pins: { youngster: "route-3/trainer-14-4" },
        shot: "route-3-box-call"
      },
      "route-14" => {
        facts: { "hm_forget" => "yes" },
        pins: { cooltrainer: "route-14/trainer-4-4" },
        shot: "route-14-hm-forget"
      },
      "fuchsia-city" => {
        facts: { "fossil_gift" => "yes" },
        pins: { house: "fuchsia-city/exit-31-27" }
      },
      "pewter-city" => {
        facts: { "dv_menu" => "yes" },
        pins: { board: "pewter-city/npc-dv-menu" }
      },
      "cerulean-city" => {
        facts: { "crits" => "na" },
        pins: { board: "cerulean-city/npc-crit-speed" }
      },
      "celadon-city" => {
        facts: { "special" => "na", "guard_spec" => "na", "coins" => "yes" },
        pins: { special: "celadon-city/npc-special-stat", guard: "celadon-city/npc-guard-spec",
                prizes: "celadon-city/exit-33-19" }
      },
      "pokemon-tower" => {
        facts: { "ghost_damage" => "na" },
        pins: { channeler: "pokemon-tower-1f/npc-ghost-damage" }
      },
      "cinnabar-island" => {
        facts: { "move_shop" => "yes" },
        pins: { lab: "cinnabar-island/exit-6-9" }
      },
      "vermilion-city-return" => {
        facts: { "badges" => "na" },
        pins: { gym: "vermilion-city/exit-12-19" }
      }
    }.freeze

    def self.attach_maps(loc, maps) = super(with_what_changed(loc), maps)

    def self.with_what_changed(loc)
      spec = WHAT_CHANGED[loc.slug]
      return loc if spec.nil?

      loc.with(trivia: loc.trivia + [
        trivia(base(loc.slug), key: "what_changed", anchor: changed_anchor(loc.slug), tagged: true,
          facts: spec.fetch(:facts), pins: spec.fetch(:pins),
          shot: (scene_shot(spec[:shot], CHANGED_SHOT_LABEL) if spec[:shot]))
      ])
    end

    CHANGED_SHOT_LABEL = "WHAT CHANGED".freeze

    def self.viridian_city
      super.with(steps: build_steps(base("viridian-city"), VIRIDIAN_STEPS))
    end

    def self.route_4
      loc("route-4", "ROUTE", "Route 4", 10,
        steps: [
          { scene: "route-4-exit", pins: { exit: "route-4/exit-24-5" } },
          { hidden: [ "Great Ball", "great-ball", "route-4-hidden-great-ball", "route-4-great-ball" ] },
          { item: [ "TM Razor Wind", "tm-razor-wind" ], scene: "route-4-item-tm-razor-wind" },
          { pins: { east: "route-4/exit-east" } }
        ])
    end

    def self.vermilion_city
      loc = super
      arrival, *rest = loc.steps
      loc.with(steps: [ arrival.with(items: vermilion_pickups) ] + rest)
    end

    def self.fuchsia_city
      loc = super
      loc.with(steps: loc.steps.map { |step| step.n == 2 ? step.with(items: []) : step })
    end

    def self.vermilion_pickups
      key_base = base("vermilion-city")
      [ item(key_base, 1, "Bike Voucher", "bike_voucher"),
        item(key_base, 1, "Good Rod", "good_rod") ]
    end



    def self.all_locations = super.map { |loc| reconcile_encounters(loc) }
  end
end
