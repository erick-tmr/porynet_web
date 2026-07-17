module Walkthrough
  module Yellow
    K = "walkthrough.yellow".freeze

    NAMES = {
      "001" => "Bulbasaur", "002" => "Ivysaur", "003" => "Venusaur", "004" => "Charmander",
      "005" => "Charmeleon", "006" => "Charizard", "007" => "Squirtle", "008" => "Wartortle",
      "009" => "Blastoise", "010" => "Caterpie", "011" => "Metapod", "012" => "Butterfree",
      "013" => "Weedle", "014" => "Kakuna", "015" => "Beedrill", "016" => "Pidgey",
      "017" => "Pidgeotto", "018" => "Pidgeot", "019" => "Rattata", "020" => "Raticate",
      "021" => "Spearow", "022" => "Fearow", "023" => "Ekans", "024" => "Arbok",
      "025" => "Pikachu", "026" => "Raichu", "027" => "Sandshrew", "028" => "Sandslash",
      "029" => "Nidoran♀", "030" => "Nidorina", "031" => "Nidoqueen", "032" => "Nidoran♂",
      "033" => "Nidorino", "034" => "Nidoking", "035" => "Clefairy", "036" => "Clefable",
      "037" => "Vulpix", "038" => "Ninetales", "039" => "Jigglypuff", "040" => "Wigglytuff",
      "041" => "Zubat", "042" => "Golbat", "043" => "Oddish", "044" => "Gloom",
      "045" => "Vileplume", "046" => "Paras", "047" => "Parasect", "048" => "Venonat",
      "049" => "Venomoth", "050" => "Diglett", "051" => "Dugtrio", "052" => "Meowth",
      "053" => "Persian", "054" => "Psyduck", "055" => "Golduck", "056" => "Mankey",
      "057" => "Primeape", "058" => "Growlithe", "059" => "Arcanine", "060" => "Poliwag",
      "061" => "Poliwhirl", "062" => "Poliwrath", "063" => "Abra", "064" => "Kadabra",
      "065" => "Alakazam", "066" => "Machop", "067" => "Machoke", "068" => "Machamp",
      "069" => "Bellsprout", "070" => "Weepinbell", "071" => "Victreebel", "072" => "Tentacool",
      "073" => "Tentacruel", "074" => "Geodude", "075" => "Graveler", "076" => "Golem",
      "077" => "Ponyta", "078" => "Rapidash", "079" => "Slowpoke", "080" => "Slowbro",
      "081" => "Magnemite", "082" => "Magneton", "083" => "Farfetch'd", "084" => "Doduo",
      "085" => "Dodrio", "086" => "Seel", "087" => "Dewgong", "088" => "Grimer",
      "089" => "Muk", "090" => "Shellder", "091" => "Cloyster", "092" => "Gastly",
      "093" => "Haunter", "094" => "Gengar", "095" => "Onix", "096" => "Drowzee",
      "097" => "Hypno", "098" => "Krabby", "099" => "Kingler", "100" => "Voltorb",
      "101" => "Electrode", "102" => "Exeggcute", "103" => "Exeggutor", "104" => "Cubone",
      "105" => "Marowak", "106" => "Hitmonlee", "107" => "Hitmonchan", "108" => "Lickitung",
      "109" => "Koffing", "110" => "Weezing", "111" => "Rhyhorn", "112" => "Rhydon",
      "113" => "Chansey", "114" => "Tangela", "115" => "Kangaskhan", "116" => "Horsea",
      "117" => "Seadra", "118" => "Goldeen", "119" => "Seaking", "120" => "Staryu",
      "121" => "Starmie", "122" => "Mr. Mime", "123" => "Scyther", "124" => "Jynx",
      "125" => "Electabuzz", "126" => "Magmar", "127" => "Pinsir", "128" => "Tauros",
      "129" => "Magikarp", "130" => "Gyarados", "131" => "Lapras", "132" => "Ditto",
      "133" => "Eevee", "134" => "Vaporeon", "135" => "Jolteon", "136" => "Flareon",
      "137" => "Porygon", "138" => "Omanyte", "139" => "Omastar", "140" => "Kabuto",
      "141" => "Kabutops", "142" => "Aerodactyl", "143" => "Snorlax", "144" => "Articuno",
      "145" => "Zapdos", "146" => "Moltres", "147" => "Dratini", "148" => "Dragonair",
      "149" => "Dragonite", "150" => "Mewtwo", "151" => "Mew"
    }.freeze

    def self.line(*dexes) = dexes.map { |d| { dex: d, name: NAMES.fetch(d) } }

    def self.mon(dex, lvl) = { dex: dex, name: NAMES.fetch(dex), lvl: lvl }

    def self.mon_key(dex) = NAMES.fetch(dex).downcase.gsub("♀", "f").gsub("♂", "m").gsub(/[^a-z]/, "")

    def self.base(slug) = "#{K}.locations.#{slug.tr('-', '_')}"

    def self.enc(slug, dex, how, rate, level, rarity, *chain, tip: false)
      Encounter.new(dex: dex, name: NAMES.fetch(dex), how: how, rate: rate, level: level,
        rarity: rarity, tip_key: (tip ? "#{base(slug)}.tips.#{mon_key(dex)}" : nil), evo_line: line(*chain))
    end

    def self.oak(slug, dex, qty)
      OakEntry.new(dex: dex, name: NAMES.fetch(dex), qty: qty, why_key: "#{base(slug)}.oak.#{mon_key(dex)}")
    end

    LEG_DEFS = [
      { slug: "leg-01", special: false, locs: %w[pallet-town route-1] },
      { slug: "leg-02", special: false, locs: %w[viridian-city route-22 route-2] },
      { slug: "viridian-forest", special: true, locs: %w[viridian-forest] },
      { slug: "leg-03", special: false, locs: %w[pewter-city route-3] },
      { slug: "mt-moon", special: true, locs: %w[mt-moon] },
      { slug: "leg-04", special: false, locs: %w[route-4 cerulean-city route-24 route-25] },
      { slug: "leg-05", special: false, locs: %w[route-5 route-6 vermilion-city] },
      { slug: "ss-anne", special: true, locs: %w[ss-anne] },
      { slug: "leg-06", special: false, locs: %w[route-11] },
      { slug: "digletts-cave", special: true, locs: %w[digletts-cave] },
      { slug: "leg-07", special: false, locs: %w[route-9 route-10] },
      { slug: "rock-tunnel", special: true, locs: %w[rock-tunnel] },
      { slug: "leg-08", special: false, locs: %w[lavender-town route-8 route-7 celadon-city] },
      { slug: "rocket-hideout", special: true, locs: %w[rocket-hideout] },
      { slug: "pokemon-tower", special: true, locs: %w[pokemon-tower] },
      { slug: "leg-09", special: false, locs: %w[route-12 route-13 route-14 route-15 fuchsia-city safari-zone] },
      { slug: "leg-10", special: false, locs: %w[route-16 route-17 route-18 saffron-city] },
      { slug: "silph-co", special: true, locs: %w[silph-co] },
      { slug: "leg-11", special: false, locs: %w[route-19 route-20] },
      { slug: "seafoam-islands", special: true, locs: %w[seafoam-islands] },
      { slug: "leg-12", special: false, locs: %w[cinnabar-island pokemon-mansion viridian-gym] },
      { slug: "victory-road", special: true, locs: %w[victory-road] },
      { slug: "leg-13", special: false, locs: %w[route-23] },
      { slug: "indigo-plateau", special: true, locs: %w[indigo-plateau] },
      { slug: "cerulean-cave", special: true, locs: %w[cerulean-cave] }
    ].freeze

    def self.game
      locations = all_locations
      by_slug = locations.to_h { |loc| [ loc.slug, loc ] }
      Game.new(
        slug: "yellow",
        name: "Pokémon Yellow",
        region: "Kanto",
        dex_goal: 151,
        oak_queue: [
          OakEntry.new(dex: "010", name: "Caterpie", qty: 1, why_key: "#{K}.slice_oak.caterpie"),
          OakEntry.new(dex: "016", name: "Pidgey", qty: 1, why_key: "#{K}.slice_oak.pidgey"),
          OakEntry.new(dex: "029", name: "Nidoran♀", qty: 1, why_key: "#{K}.slice_oak.nidoranf"),
          OakEntry.new(dex: "032", name: "Nidoran♂", qty: 1, why_key: "#{K}.slice_oak.nidoranm"),
          OakEntry.new(dex: "056", name: "Mankey", qty: 1, why_key: "#{K}.slice_oak.mankey"),
          OakEntry.new(dex: "021", name: "Spearow", qty: 1, why_key: "#{K}.slice_oak.spearow")
        ],
        locations: locations,
        legs: build_legs(by_slug)
      )
    end

    def self.all_locations
      [
        pallet_town, route_1, viridian_city, route_22, route_2, viridian_forest, pewter_city,
        route_3, mt_moon, route_4, cerulean_city, route_24, route_25,
        route_5, route_6, vermilion_city, ss_anne, route_11, digletts_cave,
        route_9, route_10, rock_tunnel, lavender_town, route_8, route_7, celadon_city, rocket_hideout,
        pokemon_tower, route_12, route_13, route_14, route_15, fuchsia_city, safari_zone,
        route_16, route_17, route_18, saffron_city, silph_co, route_19, route_20, seafoam_islands,
        cinnabar_island, pokemon_mansion, viridian_gym, victory_road, route_23, indigo_plateau, cerulean_cave
      ]
    end

    def self.build_legs(by_slug)
      LEG_DEFS.each_with_index.map { |leg_def, i| build_leg(leg_def, i + 1, by_slug) }
    end

    def self.build_leg(leg_def, order, by_slug)
      Leg.new(
        slug: leg_def[:slug], order: order, special: leg_def[:special],
        locations: leg_def[:locs].map { |s| by_slug.fetch(s) },
        lead_key: (leg_def[:special] ? nil : "#{K}.legs.#{leg_def[:slug].tr('-', '_')}.lead")
      )
    end

    def self.pallet_town
      b = base("pallet-town")
      Location.new(
        slug: "pallet-town", kind: "TOWN", name: "Pallet Town", order: 1, badge: nil,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [
          step(b, 1, items: [ item(b, 1, "Potion", "potion") ], shot: shot("STEP 1")),
          step(b, 2),
          step(b, 3),
          step(b, 4, shot: shot("STEP 4"))
        ],
        encounters: [ enc("pallet-town", "025", "STARTER", "-", "5", "GIFT", "025", "026", tip: true) ],
        trainers: [ tr("RIVAL", "Blue", 175, mon("133", 5), sprite: "blue-gen1") ],
        oak_queue: []
      )
    end

    def self.route_1
      b = base("route-1")
      Location.new(
        slug: "route-1", kind: "ROUTE", name: "Route 1", order: 2, badge: nil,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [
          step(b, 1, shot: shot("STEP 1")),
          step(b, 2, items: [ item(b, 2, "Potion", "potion") ]),
          step(b, 3)
        ],
        encounters: [
          enc("route-1", "016", "GRASS", "70%", "2–7", "COMMON", "016", "017", "018", tip: true),
          enc("route-1", "019", "GRASS", "30%", "2–4", "COMMON", "019", "020", tip: true)
        ],
        trainers: [],
        oak_queue: [ oak("route-1", "016", 1), oak("route-1", "019", 1) ]
      )
    end

    def self.viridian_city
      b = base("viridian-city")
      Location.new(
        slug: "viridian-city", kind: "CITY", name: "Viridian City", order: 3, badge: nil,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [
          step(b, 1, shot: shot("STEP 1")),
          step(b, 2),
          step(b, 3),
          step(b, 4)
        ],
        encounters: [], trainers: [], oak_queue: []
      )
    end

    def self.route_22
      b = base("route-22")
      Location.new(
        slug: "route-22", kind: "ROUTE", name: "Route 22", order: 4, badge: nil,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [
          step(b, 1, shot: shot("STEP 1")),
          step(b, 2),
          step(b, 3)
        ],
        encounters: [
          enc("route-22", "029", "GRASS", "30%", "2–4", "COMMON", "029", "030", "031", tip: true),
          enc("route-22", "032", "GRASS", "30%", "2–4", "COMMON", "032", "033", "034", tip: true),
          enc("route-22", "056", "GRASS", "20%", "3–5", "UNCOMMON", "056", "057", tip: true),
          enc("route-22", "019", "GRASS", "10%", "3", "UNCOMMON", "019", "020", tip: true),
          enc("route-22", "021", "GRASS", "10%", "2–6", "UNCOMMON", "021", "022", tip: true)
        ],
        trainers: [ tr("RIVAL", "Blue", 280, mon("021", 9), mon("133", 8), sprite: "blue-gen1") ],
        oak_queue: [
          oak("route-22", "029", 1), oak("route-22", "032", 1),
          oak("route-22", "056", 1), oak("route-22", "021", 1)
        ]
      )
    end

    def self.route_2
      b = base("route-2")
      Location.new(
        slug: "route-2", kind: "ROUTE", name: "Route 2", order: 5, badge: nil,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [
          step(b, 1, shot: shot("STEP 1")),
          step(b, 2)
        ],
        encounters: [
          enc("route-2", "016", "GRASS", "35%", "3–7", "COMMON", "016", "017", "018", tip: true),
          enc("route-2", "019", "GRASS", "35%", "3–4", "COMMON", "019", "020", tip: true),
          enc("route-2", "029", "GRASS", "15%", "4–6", "UNCOMMON", "029", "030", "031", tip: true),
          enc("route-2", "032", "GRASS", "15%", "4–6", "UNCOMMON", "032", "033", "034", tip: true)
        ],
        trainers: [], oak_queue: []
      )
    end

    def self.viridian_forest
      b = base("viridian-forest")
      Location.new(
        slug: "viridian-forest", kind: "FOREST", name: "Viridian Forest", order: 6, badge: nil,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [
          step(b, 1, items: [ item(b, 1, "Poké Ball", "poke_ball") ], shot: shot("STEP 1")),
          step(b, 2, hidden: [ hidden(b, 2, "Antidote", "antidote", "antidote.png", "vf-antidote") ]),
          step(b, 3, items: [ item(b, 3, "Potion", "potion") ], shot: shot("STEP 3")),
          step(b, 4, hidden: [ hidden(b, 4, "Potion", "potion", "potion.png", "vf-potion") ]),
          step(b, 5, shot: shot("STEP 5"))
        ],
        encounters: [
          enc("viridian-forest", "010", "GRASS", "50%", "3–6", "COMMON", "010", "011", "012", tip: true),
          enc("viridian-forest", "011", "GRASS", "25%", "4–6", "UNCOMMON", "010", "011", "012", tip: true),
          enc("viridian-forest", "016", "GRASS", "24%", "4–8", "UNCOMMON", "016", "017", "018", tip: true),
          enc("viridian-forest", "017", "GRASS", "1%", "9", "RARE", "016", "017", "018", tip: true)
        ],
        trainers: [
          tr("LASS", nil, 90, mon("029", 6), mon("032", 6)),
          tr("BUG CATCHER", nil, 70, mon("010", 7), mon("010", 7)),
          tr("BUG CATCHER", nil, 60, mon("011", 6), mon("010", 6), mon("011", 6)),
          tr("BUG CATCHER", nil, 80, mon("010", 8), mon("011", 8)),
          tr("BUG CATCHER", nil, 100, mon("010", 10))
        ],
        oak_queue: [ oak("viridian-forest", "010", 1) ]
      )
    end

    def self.pewter_city
      b = base("pewter-city")
      Location.new(
        slug: "pewter-city", kind: "CITY", name: "Pewter City", order: 7, badge: "BOULDER",
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [
          step(b, 1, shot: shot("STEP 1")),
          step(b, 2),
          step(b, 3, items: [ item(b, 3, "TM34 Bide", "tm34") ]),
          step(b, 4)
        ],
        encounters: [],
        trainers: [
          tr("JR. TRAINER♂", nil, 180, mon("050", 9), mon("027", 9)),
          leader("Brock", 1188, mon("074", 10), mon("095", 12))
        ],
        oak_queue: []
      )
    end

    def self.loc(slug, kind, name, order, steps: 3, encounters: [], trainers: [], oak_queue: [], badge: nil)
      b = base(slug)
      Location.new(
        slug: slug, kind: kind, name: name, order: order, badge: badge,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: (1..steps).map { |i| step(b, i) },
        encounters: encounters, trainers: trainers, oak_queue: oak_queue
      )
    end

    NAME_SPRITES = {
      "Brock" => "brock-gen1", "Misty" => "misty-gen1", "Lt. Surge" => "ltsurge-gen1",
      "Erika" => "erika-gen1", "Koga" => "koga-gen1", "Sabrina" => "sabrina-gen1",
      "Blaine" => "blaine-gen1", "Giovanni" => "giovanni-gen1",
      "Lorelei" => "lorelei-gen1", "Bruno" => "bruno-gen1",
      "Agatha" => "agatha-gen1", "Lance" => "lance-gen1",
      "Jessie & James" => "jessiejames-gen1"
    }.freeze

    CLASS_SPRITES = {
      "BUG CATCHER" => "bugcatcher-gen1", "LASS" => "lass-gen1",
      "JR. TRAINER♂" => "jrtrainer-gen1", "KARATE MASTER" => "blackbelt-gen1",
      "TEAM ROCKET" => "rocket-gen1", "RIVAL" => "blue-gen1", "CHAMPION" => "blue-gen1champion"
    }.freeze

    def self.trainer_sprite(cls, name) = (name && NAME_SPRITES[name]) || CLASS_SPRITES.fetch(cls)

    def self.tr(cls, name, reward, *team, sprite: nil)
      Trainer.new(cls: cls, name: name, reward: reward, team: team,
        sprite: sprite || trainer_sprite(cls, name))
    end

    def self.leader(name, reward, *team) = tr("LEADER", name, reward, *team)

    def self.rival(reward, *team) = tr("RIVAL", "Blue", reward, *team, sprite: "blue-gen1two")

    def self.route_3
      loc("route-3", "ROUTE", "Route 3", 8,
        encounters: [
          enc("route-3", "021", "GRASS", "55%", "8–12", "COMMON", "021", "022"),
          enc("route-3", "019", "GRASS", "15%", "10–12", "UNCOMMON", "019", "020"),
          enc("route-3", "027", "GRASS", "15%", "8–10", "UNCOMMON", "027", "028"),
          enc("route-3", "056", "GRASS", "15%", "9", "UNCOMMON", "056", "057")
        ],
        oak_queue: [ oak("route-3", "027", 1) ])
    end

    def self.mt_moon
      loc("mt-moon", "CAVE", "Mt. Moon", 9, steps: 4,
        encounters: [
          enc("mt-moon", "041", "CAVE", "75%", "6–11", "COMMON", "041", "042"),
          enc("mt-moon", "074", "CAVE", "15%", "8–10", "UNCOMMON", "074", "075", "076"),
          enc("mt-moon", "046", "CAVE", "5%", "8", "RARE", "046", "047"),
          enc("mt-moon", "035", "CAVE", "1%", "11", "RARE", "035", "036", tip: true)
        ],
        trainers: [ tr("TEAM ROCKET", "Jessie & James", 420,
          mon("023", 14), mon("052", 14), mon("109", 14)) ],
        oak_queue: [ oak("mt-moon", "035", 1), oak("mt-moon", "074", 1) ])
    end

    def self.route_4
      loc("route-4", "ROUTE", "Route 4", 10, steps: 2,
        encounters: [
          enc("route-4", "021", "GRASS", "55%", "8–12", "COMMON", "021", "022"),
          enc("route-4", "019", "GRASS", "15%", "10–12", "UNCOMMON", "019", "020"),
          enc("route-4", "027", "GRASS", "15%", "8–10", "UNCOMMON", "027", "028"),
          enc("route-4", "056", "GRASS", "15%", "9", "UNCOMMON", "056", "057")
        ])
    end

    def self.cerulean_city
      loc("cerulean-city", "CITY", "Cerulean City", 11, badge: "CASCADE",
        encounters: [ enc("cerulean-city", "001", "GIFT", "-", "10", "GIFT", "001", "002", "003", tip: true) ],
        trainers: [ leader("Misty", 2079, mon("120", 18), mon("121", 21)) ],
        oak_queue: [ oak("cerulean-city", "001", 1) ])
    end

    def self.route_24
      loc("route-24", "ROUTE", "Route 24", 12,
        encounters: [
          enc("route-24", "004", "GIFT", "-", "10", "GIFT", "004", "005", "006", tip: true),
          enc("route-24", "043", "GRASS", "30%", "12–14", "COMMON", "043", "044", "045"),
          enc("route-24", "069", "GRASS", "30%", "12–14", "COMMON", "069", "070", "071"),
          enc("route-24", "016", "GRASS", "29%", "13–17", "UNCOMMON", "016", "017", "018"),
          enc("route-24", "048", "GRASS", "10%", "13–16", "UNCOMMON", "048", "049")
        ],
        trainers: [ rival(595, mon("021", 18), mon("027", 15), mon("019", 15), mon("133", 17)) ],
        oak_queue: [ oak("route-24", "004", 1), oak("route-24", "043", 1), oak("route-24", "069", 1) ])
    end

    def self.route_25
      loc("route-25", "ROUTE", "Route 25", 13, steps: 2,
        encounters: [
          enc("route-25", "043", "GRASS", "30%", "12–14", "COMMON", "043", "044", "045"),
          enc("route-25", "069", "GRASS", "30%", "12–14", "COMMON", "069", "070", "071"),
          enc("route-25", "016", "GRASS", "29%", "13–17", "UNCOMMON", "016", "017", "018"),
          enc("route-25", "048", "GRASS", "10%", "13–16", "UNCOMMON", "048", "049")
        ],
        oak_queue: [ oak("route-25", "048", 1) ])
    end

    def self.route_5
      loc("route-5", "ROUTE", "Route 5", 14, steps: 2,
        encounters: [
          enc("route-5", "016", "GRASS", "40%", "15–17", "COMMON", "016", "017", "018"),
          enc("route-5", "019", "GRASS", "30%", "14–16", "COMMON", "019", "020"),
          enc("route-5", "063", "GRASS", "15%", "7", "UNCOMMON", "063", "064", "065"),
          enc("route-5", "039", "GRASS", "10%", "3–7", "UNCOMMON", "039", "040")
        ],
        oak_queue: [ oak("route-5", "063", 1) ])
    end

    def self.route_6
      loc("route-6", "ROUTE", "Route 6", 15, steps: 2,
        encounters: [
          enc("route-6", "016", "GRASS", "40%", "15–17", "COMMON", "016", "017", "018"),
          enc("route-6", "019", "GRASS", "30%", "14–16", "COMMON", "019", "020"),
          enc("route-6", "063", "GRASS", "15%", "7", "UNCOMMON", "063", "064", "065"),
          enc("route-6", "090", "SUPER ROD", "50%", "15", "COMMON", "090", "091"),
          enc("route-6", "098", "SUPER ROD", "50%", "15", "COMMON", "098", "099")
        ])
    end

    def self.vermilion_city
      loc("vermilion-city", "CITY", "Vermilion City", 16, steps: 4, badge: "THUNDER",
        encounters: [ enc("vermilion-city", "007", "GIFT", "-", "10", "GIFT", "007", "008", "009", tip: true) ],
        trainers: [ leader("Lt. Surge", 2772, mon("026", 28)) ],
        oak_queue: [ oak("vermilion-city", "007", 1) ])
    end

    def self.ss_anne
      loc("ss-anne", "BUILDING", "S.S. Anne", 17, steps: 3,
        trainers: [ rival(1300, mon("021", 19), mon("019", 16), mon("027", 18), mon("133", 20)) ])
    end

    def self.route_11
      loc("route-11", "ROUTE", "Route 11", 18, steps: 2,
        encounters: [
          enc("route-11", "016", "GRASS", "40%", "16–18", "COMMON", "016", "017", "018"),
          enc("route-11", "019", "GRASS", "25%", "15–17", "UNCOMMON", "019", "020"),
          enc("route-11", "096", "GRASS", "24%", "15–19", "UNCOMMON", "096", "097")
        ],
        oak_queue: [ oak("route-11", "096", 1) ])
    end

    def self.digletts_cave
      loc("digletts-cave", "CAVE", "Diglett's Cave", 19, steps: 2,
        encounters: [
          enc("digletts-cave", "050", "CAVE", "95%", "15–22", "COMMON", "050", "051"),
          enc("digletts-cave", "051", "CAVE", "5%", "29–31", "RARE", "050", "051")
        ],
        oak_queue: [ oak("digletts-cave", "050", 1) ])
    end

    def self.pokemon_tower
      loc("pokemon-tower", "DUNGEON", "Pokémon Tower", 28, steps: 4,
        encounters: [
          enc("pokemon-tower", "092", "FLOORS", "90%", "18–29", "COMMON", "092", "093", "094", tip: true),
          enc("pokemon-tower", "104", "FLOORS", "5%", "20–24", "RARE", "104", "105")
        ],
        trainers: [
          rival(1625, mon("022", 25), mon("027", 20), mon("037", 23), mon("081", 22), mon("133", 25)),
          tr("TEAM ROCKET", "Jessie & James", 810,
            mon("052", 27), mon("024", 27), mon("110", 27))
        ],
        oak_queue: [ oak("pokemon-tower", "092", 1), oak("pokemon-tower", "104", 1) ])
    end

    def self.route_12
      loc("route-12", "ROUTE", "Route 12", 29, steps: 3,
        encounters: [
          enc("route-12", "043", "GRASS", "30%", "22–26", "COMMON", "043", "044", "045"),
          enc("route-12", "069", "GRASS", "30%", "22–26", "COMMON", "069", "070", "071"),
          enc("route-12", "079", "SURF", "95%", "15", "COMMON", "079", "080"),
          enc("route-12", "083", "GRASS", "5%", "26–31", "RARE", "083", tip: true),
          enc("route-12", "143", "STATIC", "-", "30", "STATIC", "143", tip: true)
        ],
        oak_queue: [ oak("route-12", "079", 1), oak("route-12", "083", 1) ])
    end

    def self.route_13
      loc("route-13", "ROUTE", "Route 13", 30, steps: 2,
        encounters: [
          enc("route-13", "043", "GRASS", "30%", "22–27", "COMMON", "043", "044", "045"),
          enc("route-13", "069", "GRASS", "30%", "22–27", "COMMON", "069", "070", "071"),
          enc("route-13", "016", "GRASS", "10%", "25–28", "UNCOMMON", "016", "017", "018"),
          enc("route-13", "132", "GRASS", "5%", "25", "RARE", "132", tip: true)
        ],
        oak_queue: [ oak("route-13", "132", 1) ])
    end

    def self.route_14
      loc("route-14", "ROUTE", "Route 14", 31, steps: 2,
        encounters: [
          enc("route-14", "043", "GRASS", "30%", "22–28", "COMMON", "043", "044", "045"),
          enc("route-14", "069", "GRASS", "30%", "22–28", "COMMON", "069", "070", "071"),
          enc("route-14", "048", "GRASS", "19%", "24–27", "UNCOMMON", "048", "049"),
          enc("route-14", "049", "GRASS", "1%", "30", "RARE", "048", "049")
        ])
    end

    def self.route_15
      loc("route-15", "ROUTE", "Route 15", 32, steps: 2,
        encounters: [
          enc("route-15", "043", "GRASS", "30%", "22–28", "COMMON", "043", "044", "045"),
          enc("route-15", "069", "GRASS", "30%", "22–28", "COMMON", "069", "070", "071"),
          enc("route-15", "048", "GRASS", "9%", "24–28", "RARE", "048", "049")
        ])
    end

    def self.fuchsia_city
      loc("fuchsia-city", "CITY", "Fuchsia City", 33, steps: 4, badge: "SOUL",
        encounters: [
          enc("fuchsia-city", "130", "SUPER ROD", "10%", "15", "UNCOMMON", "129", "130", tip: true)
        ],
        trainers: [ leader("Koga", 4950, mon("048", 44), mon("048", 46), mon("048", 48), mon("049", 50)) ],
        oak_queue: [ oak("fuchsia-city", "130", 1) ])
    end

    def self.safari_zone
      loc("safari-zone", "DUNGEON", "Safari Zone", 34, steps: 4,
        encounters: [
          enc("safari-zone", "123", "SAFARI", "4%", "23", "RARE", "123", tip: true),
          enc("safari-zone", "127", "SAFARI", "4%", "23", "RARE", "127", tip: true),
          enc("safari-zone", "115", "SAFARI", "4%", "25", "RARE", "115", tip: true),
          enc("safari-zone", "128", "SAFARI", "10%", "21", "UNCOMMON", "128"),
          enc("safari-zone", "113", "SAFARI", "1%", "7", "RARE", "113", tip: true),
          enc("safari-zone", "114", "SAFARI", "4%", "22", "RARE", "114"),
          enc("safari-zone", "102", "SAFARI", "15%", "24", "UNCOMMON", "102", "103"),
          enc("safari-zone", "147", "SUPER ROD", "10%", "15", "UNCOMMON", "147", "148", "149", tip: true)
        ],
        oak_queue: [
          oak("safari-zone", "123", 1), oak("safari-zone", "127", 1),
          oak("safari-zone", "147", 1), oak("safari-zone", "115", 1)
        ])
    end

    def self.route_16
      loc("route-16", "ROUTE", "Route 16", 35, steps: 3,
        encounters: [
          enc("route-16", "084", "GRASS", "40%", "22–26", "COMMON", "084", "085"),
          enc("route-16", "019", "GRASS", "30%", "23–24", "COMMON", "019", "020"),
          enc("route-16", "021", "GRASS", "25%", "22–23", "UNCOMMON", "021", "022"),
          enc("route-16", "143", "STATIC", "-", "30", "STATIC", "143", tip: true)
        ],
        oak_queue: [ oak("route-16", "084", 1), oak("route-16", "143", 1) ])
    end

    def self.route_17
      loc("route-17", "ROUTE", "Route 17", 36, steps: 2,
        encounters: [
          enc("route-17", "084", "GRASS", "50%", "26–28", "COMMON", "084", "085"),
          enc("route-17", "077", "GRASS", "24%", "28–32", "UNCOMMON", "077", "078"),
          enc("route-17", "022", "GRASS", "25%", "27–29", "UNCOMMON", "021", "022"),
          enc("route-17", "085", "GRASS", "1%", "29", "RARE", "084", "085")
        ],
        oak_queue: [ oak("route-17", "077", 1) ])
    end

    def self.route_18
      loc("route-18", "ROUTE", "Route 18", 37, steps: 2,
        encounters: [
          enc("route-18", "021", "GRASS", "40%", "20–22", "COMMON", "021", "022"),
          enc("route-18", "019", "GRASS", "25%", "23–24", "UNCOMMON", "019", "020"),
          enc("route-18", "084", "GRASS", "25%", "24–28", "UNCOMMON", "084", "085")
        ])
    end

    def self.saffron_city
      loc("saffron-city", "CITY", "Saffron City", 38, steps: 4, badge: "MARSH",
        trainers: [
          leader("Sabrina", 4950, mon("063", 50), mon("064", 50), mon("065", 50)),
          tr("KARATE MASTER", nil, 925, mon("106", 37), mon("107", 37))
        ],
        oak_queue: [ oak("saffron-city", "106", 1) ])
    end

    def self.silph_co
      loc("silph-co", "BUILDING", "Silph Co.", 39, steps: 4,
        encounters: [ enc("silph-co", "131", "GIFT", "-", "15", "GIFT", "131", tip: true) ],
        trainers: [
          rival(0, mon("022", 37), mon("085", 38), mon("103", 38), mon("133", 40)),
          tr("TEAM ROCKET", "Giovanni", 4059,
            mon("033", 37), mon("111", 37), mon("053", 35), mon("031", 41))
        ],
        oak_queue: [ oak("silph-co", "131", 1) ])
    end

    def self.route_19
      loc("route-19", "ROUTE", "Route 19", 40, steps: 2,
        encounters: [
          enc("route-19", "072", "SURF", "100%", "5–40", "COMMON", "072", "073"),
          enc("route-19", "120", "SUPER ROD", "30%", "20", "COMMON", "120", "121"),
          enc("route-19", "116", "SUPER ROD", "25%", "15", "UNCOMMON", "116", "117"),
          enc("route-19", "090", "SUPER ROD", "25%", "15", "UNCOMMON", "090", "091")
        ])
    end

    def self.route_20
      loc("route-20", "ROUTE", "Route 20", 41, steps: 2,
        encounters: [
          enc("route-20", "072", "SURF", "100%", "5–40", "COMMON", "072", "073"),
          enc("route-20", "120", "SUPER ROD", "45%", "15–30", "COMMON", "120", "121"),
          enc("route-20", "116", "SUPER ROD", "25%", "15", "UNCOMMON", "116", "117")
        ])
    end

    def self.seafoam_islands
      loc("seafoam-islands", "CAVE", "Seafoam Islands", 42, steps: 4,
        encounters: [
          enc("seafoam-islands", "086", "CAVE", "15%", "28–30", "UNCOMMON", "086", "087"),
          enc("seafoam-islands", "090", "CAVE", "19%", "28–30", "UNCOMMON", "090", "091"),
          enc("seafoam-islands", "098", "CAVE", "35%", "25–27", "COMMON", "098", "099"),
          enc("seafoam-islands", "054", "CAVE", "20%", "30", "UNCOMMON", "054", "055"),
          enc("seafoam-islands", "079", "CAVE", "15%", "28–30", "UNCOMMON", "079", "080"),
          enc("seafoam-islands", "144", "STATIC", "-", "50", "STATIC", "144", tip: true)
        ],
        oak_queue: [ oak("seafoam-islands", "086", 1), oak("seafoam-islands", "144", 1) ])
    end

    def self.cinnabar_island
      loc("cinnabar-island", "TOWN", "Cinnabar Island", 43, steps: 4, badge: "VOLCANO",
        encounters: [
          enc("cinnabar-island", "138", "FOSSIL", "-", "30", "GIFT", "138", "139", tip: true),
          enc("cinnabar-island", "140", "FOSSIL", "-", "30", "GIFT", "140", "141", tip: true),
          enc("cinnabar-island", "142", "FOSSIL", "-", "30", "GIFT", "142", tip: true),
          enc("cinnabar-island", "072", "SURF", "100%", "5–40", "COMMON", "072", "073"),
          enc("cinnabar-island", "120", "SUPER ROD", "30%", "15–30", "UNCOMMON", "120", "121")
        ],
        trainers: [ leader("Blaine", 5346, mon("038", 48), mon("078", 50), mon("059", 54)) ],
        oak_queue: [ oak("cinnabar-island", "138", 1), oak("cinnabar-island", "140", 1), oak("cinnabar-island", "142", 1) ])
    end

    def self.pokemon_mansion
      loc("pokemon-mansion", "BUILDING", "Pokémon Mansion", 44, steps: 3,
        encounters: [
          enc("pokemon-mansion", "037", "FLOORS", "15%", "32–35", "UNCOMMON", "037", "038", tip: true),
          enc("pokemon-mansion", "058", "FLOORS", "15%", "32–35", "UNCOMMON", "058", "059", tip: true),
          enc("pokemon-mansion", "109", "FLOORS", "40%", "30–35", "COMMON", "109", "110"),
          enc("pokemon-mansion", "088", "FLOORS", "30%", "23–38", "COMMON", "088", "089"),
          enc("pokemon-mansion", "126", "FLOORS", "5%", "34–38", "RARE", "126", tip: true),
          enc("pokemon-mansion", "132", "FLOORS", "10%", "12–24", "UNCOMMON", "132")
        ],
        oak_queue: [ oak("pokemon-mansion", "037", 1), oak("pokemon-mansion", "058", 1), oak("pokemon-mansion", "126", 1) ])
    end

    def self.viridian_gym
      loc("viridian-gym", "GYM", "Viridian Gym", 45, steps: 3, badge: "EARTH",
        trainers: [ leader("Giovanni", 5445, mon("051", 50), mon("053", 53), mon("031", 53), mon("034", 55), mon("112", 55)) ])
    end

    def self.victory_road
      loc("victory-road", "CAVE", "Victory Road", 46, steps: 4,
        encounters: [
          enc("victory-road", "074", "CAVE", "30%", "26–46", "COMMON", "074", "075", "076"),
          enc("victory-road", "066", "CAVE", "20%", "22–24", "UNCOMMON", "066", "067", "068"),
          enc("victory-road", "095", "CAVE", "20%", "36–47", "UNCOMMON", "095"),
          enc("victory-road", "105", "CAVE", "4%", "40–43", "RARE", "104", "105"),
          enc("victory-road", "146", "STATIC", "-", "50", "STATIC", "146", tip: true)
        ],
        oak_queue: [ oak("victory-road", "146", 1) ])
    end

    def self.route_23
      loc("route-23", "ROUTE", "Route 23", 47, steps: 3,
        encounters: [
          enc("route-23", "132", "GRASS", "35%", "33–43", "COMMON", "132"),
          enc("route-23", "056", "GRASS", "20%", "36–41", "UNCOMMON", "056", "057"),
          enc("route-23", "022", "GRASS", "15%", "40–45", "UNCOMMON", "021", "022"),
          enc("route-23", "024", "GRASS", "5%", "41", "RARE", "023", "024")
        ])
    end

    def self.indigo_plateau
      loc("indigo-plateau", "BUILDING", "Indigo Plateau", 48, steps: 3,
        trainers: [
          tr("ELITE FOUR", "Lorelei", 5544,
            mon("087", 54), mon("091", 53), mon("080", 54), mon("124", 56), mon("131", 56)),
          tr("ELITE FOUR", "Bruno", 5742,
            mon("095", 53), mon("107", 55), mon("106", 55), mon("095", 56), mon("068", 58)),
          tr("ELITE FOUR", "Agatha", 5940,
            mon("094", 56), mon("042", 56), mon("093", 55), mon("024", 58), mon("094", 60)),
          tr("ELITE FOUR", "Lance", 6138,
            mon("130", 58), mon("148", 56), mon("148", 56), mon("142", 60), mon("149", 62)),
          tr("CHAMPION", "Blue", 6435,
            mon("028", 61), mon("065", 59), mon("103", 61), mon("091", 61), mon("038", 63), mon("135", 65))
        ])
    end

    def self.cerulean_cave
      loc("cerulean-cave", "CAVE", "Cerulean Cave", 49, steps: 4,
        encounters: [
          enc("cerulean-cave", "042", "CAVE", "40%", "50–55", "COMMON", "041", "042"),
          enc("cerulean-cave", "112", "CAVE", "15%", "58–62", "UNCOMMON", "111", "112"),
          enc("cerulean-cave", "113", "CAVE", "10%", "55–60", "UNCOMMON", "113"),
          enc("cerulean-cave", "132", "CAVE", "15%", "55–65", "UNCOMMON", "132"),
          enc("cerulean-cave", "026", "CAVE", "4%", "53–64", "RARE", "025", "026"),
          enc("cerulean-cave", "150", "STATIC", "-", "70", "STATIC", "150", tip: true)
        ],
        oak_queue: [ oak("cerulean-cave", "150", 1), oak("cerulean-cave", "113", 1) ])
    end

    def self.route_9
      loc("route-9", "ROUTE", "Route 9", 20, steps: 3,
        encounters: [
          enc("route-9", "032", "GRASS", "30%", "16–18", "COMMON", "032", "033", "034"),
          enc("route-9", "029", "GRASS", "30%", "16–18", "COMMON", "029", "030", "031"),
          enc("route-9", "019", "GRASS", "15%", "18", "UNCOMMON", "019", "020"),
          enc("route-9", "021", "GRASS", "10%", "17", "UNCOMMON", "021", "022")
        ])
    end

    def self.route_10
      loc("route-10", "ROUTE", "Route 10", 21, steps: 3,
        encounters: [
          enc("route-10", "081", "GRASS", "50%", "16–22", "COMMON", "081", "082"),
          enc("route-10", "019", "GRASS", "20%", "18", "UNCOMMON", "019", "020"),
          enc("route-10", "032", "GRASS", "10%", "17", "UNCOMMON", "032", "033", "034"),
          enc("route-10", "066", "GRASS", "5%", "16–18", "RARE", "066", "067", "068")
        ],
        oak_queue: [ oak("route-10", "081", 1) ])
    end

    def self.rock_tunnel
      loc("rock-tunnel", "CAVE", "Rock Tunnel", 22, steps: 3,
        encounters: [
          enc("rock-tunnel", "041", "CAVE", "50%", "15–21", "COMMON", "041", "042"),
          enc("rock-tunnel", "074", "CAVE", "40%", "16–20", "COMMON", "074", "075", "076"),
          enc("rock-tunnel", "066", "CAVE", "10%", "17–21", "UNCOMMON", "066", "067", "068"),
          enc("rock-tunnel", "095", "CAVE", "10%", "14–22", "UNCOMMON", "095")
        ],
        oak_queue: [ oak("rock-tunnel", "066", 1), oak("rock-tunnel", "095", 1) ])
    end

    def self.lavender_town
      loc("lavender-town", "TOWN", "Lavender Town", 23, steps: 3)
    end

    def self.route_8
      loc("route-8", "ROUTE", "Route 8", 24, steps: 2,
        encounters: [
          enc("route-8", "016", "GRASS", "40%", "20–22", "COMMON", "016", "017", "018"),
          enc("route-8", "063", "GRASS", "20%", "15–19", "UNCOMMON", "063", "064", "065"),
          enc("route-8", "019", "GRASS", "15%", "20", "UNCOMMON", "019", "020"),
          enc("route-8", "039", "GRASS", "10%", "19–24", "UNCOMMON", "039", "040")
        ])
    end

    def self.route_7
      loc("route-7", "ROUTE", "Route 7", 25, steps: 2,
        encounters: [
          enc("route-7", "016", "GRASS", "40%", "20–22", "COMMON", "016", "017", "018"),
          enc("route-7", "063", "GRASS", "25%", "15–26", "UNCOMMON", "063", "064", "065"),
          enc("route-7", "019", "GRASS", "15%", "20", "UNCOMMON", "019", "020"),
          enc("route-7", "039", "GRASS", "10%", "19–24", "UNCOMMON", "039", "040")
        ])
    end

    def self.celadon_city
      loc("celadon-city", "CITY", "Celadon City", 26, steps: 4, badge: "RAINBOW",
        encounters: [
          enc("celadon-city", "133", "GIFT", "-", "25", "GIFT", "133", tip: true),
          enc("celadon-city", "137", "GAME CORNER", "9999", "26", "GIFT", "137", tip: true),
          enc("celadon-city", "037", "GAME CORNER", "1000", "18", "GIFT", "037", "038", tip: true)
        ],
        trainers: [ leader("Erika", 3168, mon("114", 30), mon("070", 32), mon("044", 32)) ],
        oak_queue: [ oak("celadon-city", "133", 1), oak("celadon-city", "137", 1) ])
    end

    def self.rocket_hideout
      loc("rocket-hideout", "DUNGEON", "Rocket Hideout", 27, steps: 4,
        trainers: [
          tr("TEAM ROCKET", "Jessie & James", 750,
            mon("109", 25), mon("052", 25), mon("023", 25)),
          tr("TEAM ROCKET", "Giovanni", 2871,
            mon("095", 25), mon("111", 24), mon("053", 29))
        ])
    end

    def self.step(base, n, items: [], hidden: [], shot: nil)
      Step.new(n: n, title_key: "#{base}.steps.#{n}.title", text_key: "#{base}.steps.#{n}.text",
        items: items, hidden: hidden, shot: shot)
    end

    ITEM_SPRITES = { "TM34 Bide" => "tm-normal" }.freeze

    def self.item_sprite(name)
      ITEM_SPRITES.fetch(name) { name.downcase.gsub("é", "e").gsub(/[^a-z0-9]+/, "-") }
    end

    def self.item(base, n, name, key)
      Item.new(name: name, where_key: "#{base}.steps.#{n}.items.#{key}", sprite: item_sprite(name))
    end

    def self.hidden(base, n, name, key, image, pin)
      HiddenItem.new(name: name, where_key: "#{base}.steps.#{n}.hidden.#{key}",
        image: "walkthrough/yellow/viridian-forest/#{image}", pin: pin, sprite: item_sprite(name))
    end

    def self.shot(label) = Shot.new(image: nil, label: label)
  end
end
