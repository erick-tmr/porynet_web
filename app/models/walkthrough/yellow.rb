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

    RIVAL_EEVEE_ANCHOR = "rival-eevee"

    def self.enc(slug, dex, how, rate, level, rarity, *chain, tip: false)
      Encounter.new(dex: dex, name: NAMES.fetch(dex), how: how, rate: rate, level: level,
        rarity: rarity, tip_key: (tip ? "#{base(slug)}.tips.#{mon_key(dex)}" : nil), evo_line: line(*chain))
    end

    def self.oak(slug, dex, qty)
      OakEntry.new(dex: dex, name: NAMES.fetch(dex), qty: qty, why_key: "#{base(slug)}.oak.#{mon_key(dex)}")
    end

    def self.trade(slug, key, give, receive, nick, house:, inside:)
      b = base(slug)
      Trade.new(
        give: { dex: give, name: NAMES.fetch(give) },
        receive: { dex: receive, name: NAMES.fetch(receive) },
        nick: nick, npc_key: "#{b}.trades.#{key}.npc", title_key: "#{b}.trades.#{key}.title",
        where_key: "#{b}.trades.#{key}.where", note_key: "#{b}.trades.#{key}.note",
        house: scene_shot(house, WHERE_LABEL), inside: scene_shot(inside, INSIDE_LABEL)
      )
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
      { slug: "power-plant", special: true, locs: %w[power-plant] },
      { slug: "leg-12", special: false, locs: %w[cinnabar-island pokemon-mansion route-21 viridian-gym] },
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
        legs: build_legs(by_slug),
        best_catches: compute_best_catches(locations)
      )
    end

    def self.parse_rate(rate)
      match = rate.match(/\A(\d+)%\z/)
      match && match[1].to_i
    end

    def self.compute_best_catches(locations)
      by_dex = Hash.new { |hash, dex| hash[dex] = [] }
      locations.each do |loc|
        loc.encounters.each do |enc|
          by_dex[enc.dex] << { loc: loc, enc: enc, pct: parse_rate(enc.rate) } if enc.wild?
        end
      end
      by_dex.each_with_object({}) do |(dex, entries), best|
        found = entries.one? ? sole_catch(dex, entries.first) : ranked_catch(dex, entries)
        best[dex] = found if found
      end
    end

    def self.sole_catch(dex, entry)
      BestCatch.new(
        dex: dex, slug: entry[:loc].slug, only: true,
        rate: entry[:pct] ? entry[:enc].rate : nil
      )
    end

    def self.ranked_catch(dex, entries)
      rated = entries.select { |e| e[:pct] }
      top = rated.map { |e| e[:pct] }.max
      winner = rated.select { |e| e[:pct] == top }.min_by { |e| e[:loc].order }
      runner = rated.reject { |e| e.equal?(winner) }.max_by { |e| e[:pct] }
      return nil unless runner

      BestCatch.new(
        dex: dex, slug: winner[:loc].slug, rate: winner[:enc].rate,
        tie: rated.count { |e| e[:pct] == top } > 1,
        alt_name: runner[:loc].name, alt_rate: runner[:enc].rate
      )
    end

    def self.all_locations
      data = map_data
      [
        pallet_town, route_1, viridian_city, route_22, route_2, viridian_forest, pewter_city,
        route_3, mt_moon, route_4, cerulean_city, route_24, route_25,
        route_5, route_6, vermilion_city, ss_anne, route_11, digletts_cave,
        route_9, route_10, rock_tunnel, lavender_town, route_8, route_7, celadon_city, rocket_hideout,
        pokemon_tower, route_12, route_13, route_14, route_15, fuchsia_city, safari_zone,
        route_16, route_17, route_18, saffron_city, silph_co, route_19, route_20, seafoam_islands,
        power_plant, cinnabar_island, pokemon_mansion, route_21, viridian_gym, victory_road, route_23,
        indigo_plateau, cerulean_cave
      ].map { |loc| attach_maps(loc, data.fetch(loc.slug, [])) }
    end

    # The gym's own map belongs in the gym section, not the location header, so pull the "Gym"
    # floor out of the header maps and hand it to the gym as its shot.
    def self.attach_maps(loc, maps)
      gym_map = maps.find { |m| m.floor == "Gym" }
      header = maps.reject { |m| m.floor == "Gym" }
      loc = tick_items(merge_trainers(loc), header)
      return loc.with(area_maps: header) unless loc.gym && gym_map

      loc.with(area_maps: header,
        gym: loc.gym.with(shot: Shot.new(image: gym_map.image, label: loc.gym.shot.label)))
    end

    def self.merge_trainers(loc)
      claimed = {}
      fresh = roster_for(loc.slug).reject do |entry|
        card = authored_cards(loc).find { |t| t.opp == entry["opp"] }
        claimed[entry["opp"]] = enrich(card, entry) if card
        card
      end
      place_trainers(loc, fresh, claimed)
    end

    def self.tick_items(loc, maps)
      pins = maps.flat_map { |m| m.markers.map { |k| [ m.name, k ] } }
      loc.with(steps: loc.steps.map do |step|
        step.with(items: step.items.map { |i| i.with(tick: pin_tick(pins, "item", i)) },
          hidden: step.hidden.map { |h| h.with(tick: pin_tick(pins, "hidden", h)) })
      end)
    end

    def self.pin_tick(pins, cat, item)
      found = pins.select { |_name, pin| pin.cat == cat && pin.name == item.name }
      found = found.select { |_name, pin| pin.id.end_with?("-#{item.at[0]}-#{item.at[1]}") } if item.at
      return nil unless found.one?

      map_name, pin = found.first
      "#{map_name}/#{pin.id}"
    end

    def self.authored_cards(loc)
      loc.trainers + (loc.gym ? loc.gym.trainers + [ loc.gym.leader ] : [])
    end

    def self.gym_entry?(loc, entry) = entry["floor"] == "Gym" || loc.kind == "GYM"

    def self.place_trainers(loc, fresh, claimed)
      gym_fresh, loc_fresh = fresh.partition { |e| gym_entry?(loc, e) }
      loc = loc.with(trainers: settle(loc.trainers, loc_fresh, claimed))
      return loc unless loc.gym

      loc.with(gym: loc.gym.with(trainers: settle(loc.gym.trainers, gym_fresh, claimed),
        leader: claimed.fetch(loc.gym.leader.opp, loc.gym.leader)))
    end

    def self.settle(authored, fresh, claimed)
      authored.map { |t| claimed.fetch(t.opp, t) } + fresh.map { |e| roster_trainer(e) }
    end

    def self.enrich(card, entry)
      card.with(where: card.where || Shot.new(image: entry["where"], label: WHERE_LABEL),
        marker_key: card.marker_key || entry["key"], tick: card.tick || tick_for(entry))
    end

    def self.roster_trainer(entry)
      label = class_label(entry["cls"])
      Trainer.new(cls: label, name: nil, reward: entry["reward"],
        team: entry["team"].map { |m| mon(m["dex"], m["lvl"]) },
        sprite: trainer_sprite(label, nil),
        where: Shot.new(image: entry["where"], label: WHERE_LABEL), battle: nil,
        opp: entry["opp"], marker_key: entry["key"], tick: tick_for(entry))
    end

    def self.tick_for(entry) = "#{entry['map']}/#{entry['marker']}"

    def self.roster_for(slug) = roster.fetch("trainers", {}).fetch(slug, [])

    def self.roster
      @roster ||= JSON.parse(File.read(File.join(__dir__, "yellow_trainers.json"))).freeze
    end

    def self.manifest
      @manifest ||= JSON.parse(File.read(File.join(__dir__, "yellow_maps.json"))).freeze
    end

    # Item-givers and easter-egg NPCs are curated, not derivable from the map data the way
    # trainers and item balls are, so they live in a hand-authored overlay keyed by map name
    # and join onto the generated markers at load. Positions are the game's own object
    # coordinates, turned into percentages here the same way the generator does.
    def self.npc_overlay
      @npc_overlay ||= JSON.parse(File.read(File.join(__dir__, "yellow_npcs.json"))).freeze
    end

    def self.map_data
      manifest.fetch("locations").transform_values do |maps|
        maps.map do |m|
          base = m.fetch("markers", []).map { |k| map_marker(k) }
          # NPC letters carry on from the map's trainers so a person is one A, B, C... sequence and
          # no NPC ever wears the same letter as a trainer standing on the same map.
          trainers = base.count { |marker| marker.cat == "trainer" }
          npcs = npc_overlay.fetch(m["name"], []).each_with_index.map do |n, i|
            npc_marker(n, m["width"], m["height"], key_letter(trainers + i))
          end
          AreaMap.new(image: m["image"], width: m["width"], height: m["height"], floor: m["floor"],
            name: m["name"], markers: base + npcs)
        end
      end
    end

    # A few places do something the map data cannot state (the Name Rater renames a Pokémon but
    # gives nothing; the Viridian house is pure flavor), so a hand-authored overlay keyed by map
    # const pins a locale key onto them, the same curated-overlay pattern as the NPC markers.
    def self.place_notes
      @place_notes ||= JSON.parse(File.read(File.join(__dir__, "yellow_place_notes.json"))).freeze
    end

    # What is behind each door, generated from the disassembly next to the map manifest.
    def self.place_facts
      @place_facts ||= JSON.parse(File.read(File.join(__dir__, "yellow_places.json")))
        .fetch("places").to_h { |const, facts| [ const, place(const, facts) ] }.freeze
    end

    def self.place(const, facts)
      Place.new(kind: facts["kind"], note: place_notes[const], gym: gym_facts(facts["gym"]),
        stock: facts.fetch("stock", []),
        gift_item: facts.fetch("gift_item", []).map { |i| GiftItem.new(name: i["name"], qty: i["qty"]) },
        gift_mon: facts.fetch("gift_mon", []).map { |g| gift(g) },
        trainers: facts.fetch("trainers", 0), items: facts.fetch("items", 0))
    end

    def self.gift(data)
      Gift.new(dex: data["dex"], name: NAMES.fetch(data["dex"]), level: data["level"],
        sold: data["sold"])
    end

    def self.gym_facts(data)
      return nil if data.nil?

      GymFacts.new(leader: data["leader"], types: data["types"], badge: data["badge"],
        tm: data["tm"])
    end

    def self.map_marker(data)
      MapMarker.new(id: data["id"], cat: data["cat"], key: data["key"], name: data["name"],
        x: data["x"], y: data["y"], align: data["align"], lane: data["lane"],
        glyph: data["glyph"], edge: data["edge"], ref: data["ref"],
        place: (place_facts[data["ref"]] if data["cat"] == "exit"))
    end

    CELL_PX = 16

    def self.npc_marker(data, width, height, key)
      gx, gy = data["grid"]
      x = ((gx * CELL_PX + CELL_PX / 2).to_f / width * 100).round(3)
      y = ((gy * CELL_PX + CELL_PX / 2).to_f / height * 100).round(3)
      MapMarker.new(id: data["id"], cat: "npc", key: key, name: data["name"],
        x: x, y: y, align: data.fetch("align") { x > 62 ? "l" : "r" }, lane: data.fetch("lane", 0),
        note: data["note"], ref: data["ref"])
    end

    # 0 -> A, 25 -> Z, 26 -> AA, mirroring the generator's key_letters so map and overlay agree.
    def self.key_letter(index)
      out = ("A".ord + index % 26).chr
      index /= 26
      while index.positive?
        index -= 1
        out = ("A".ord + index % 26).chr + out
        index /= 26
      end
      out
    end

    def self.step_shots = manifest.fetch("step_shots", {})

    def self.map_shot(slug, step_n, label)
      data = step_shots.dig(slug, step_n.to_s)
      data ? Shot.new(image: data["image"], label: label) : shot(label)
    end

    def self.scenes = manifest.fetch("scenes", {})

    def self.scene_shot(key, label)
      data = scenes[key]
      data ? Shot.new(image: data["image"], label: label) : shot(label)
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
          step(b, 1, items: [ item(b, 1, "Potion", "potion") ], shot: map_shot("pallet-town", 1, "STEP 1")),
          step(b, 2),
          step(b, 3, html: true, link: StepLink.new(leg: "leg-01", anchor: RIVAL_EEVEE_ANCHOR)),
          step(b, 4, shot: map_shot("pallet-town", 4, "STEP 4"))
        ],
        encounters: [ enc("pallet-town", "025", "STARTER", "-", "5", "GIFT", "025", "026", tip: true) ],
        trainers: [ tr("RIVAL", "Blue", 175, mon("133", 5), sprite: "blue-gen1",
          where: scene_shot("oaks-lab-rival", "WHERE"),
          battle: scene_shot("battle-rival-oaks-lab", "BATTLE")) ],
        oak_queue: [],
        trivia: trivia(b, anchor: RIVAL_EEVEE_ANCHOR, cards: [
          trivia_card(b, "vaporeon", "134", "water", "no", "na"),
          trivia_card(b, "jolteon", "135", "electric", "yes", "yes"),
          trivia_card(b, "flareon", "136", "fire", "yes", "no")
        ])
      )
    end

    def self.route_1
      b = base("route-1")
      Location.new(
        slug: "route-1", kind: "ROUTE", name: "Route 1", order: 2, badge: nil,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [
          step(b, 1, shot: map_shot("route-1", 1, "STEP 1")),
          step(b, 2, items: [ item(b, 2, "Potion", "potion") ]),
          step(b, 3)
        ],
        encounters: [
          enc("route-1", "016", "GRASS", "70%", "2–7", "COMMON", "016", "017", "018", tip: true),
          enc("route-1", "019", "GRASS", "30%", "2–4", "COMMON", "019", "020", tip: true)
        ],
        trainers: [],
        oak_queue: []
      )
    end

    def self.viridian_city
      b = base("viridian-city")
      Location.new(
        slug: "viridian-city", kind: "CITY", name: "Viridian City", order: 3, badge: nil,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [
          step(b, 1, items: [ item(b, 1, "Oak's Parcel", "oaks_parcel") ],
            shot: map_shot("viridian-city", 1, "STEP 1")),
          step(b, 2),
          step(b, 3, items: [ item(b, 3, "Town Map", "town_map") ],
            shot: map_shot("viridian-city", 3, "STEP 3")),
          step(b, 4, html: true, hidden: [ hidden(b, 4, "Potion", "potion", "viridian-city-hidden-potion", "viridian-potion") ]),
          step(b, 5)
        ],
        encounters: [], trainers: [], oak_queue: [],
        later: [ later(b, "tm42", "TM42 Dream Eater", "ITEM", "Cut or Surf", "viridian-city-tm42") ],
        missable: missable(b, anchor: "missable-poke-balls", after_step: 3)
      )
    end

    def self.route_22
      b = base("route-22")
      Location.new(
        slug: "route-22", kind: "ROUTE", name: "Route 22", order: 4, badge: nil,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [
          step(b, 1, shot: map_shot("route-22", 1, "STEP 1")),
          step(b, 2, html: true, link: StepLink.new(leg: "leg-01", anchor: RIVAL_EEVEE_ANCHOR)),
          step(b, 3, html: true, shot: map_shot("route-22", 3, "STEP 3")),
          step(b, 4, shot: map_shot("route-22", 4, "STEP 4"))
        ],
        encounters: [
          enc("route-22", "029", "GRASS", "30%", "2–4", "COMMON", "029", "030", "031", tip: true),
          enc("route-22", "032", "GRASS", "30%", "2–4", "COMMON", "032", "033", "034", tip: true),
          enc("route-22", "056", "GRASS", "20%", "3–5", "UNCOMMON", "056", "057", tip: true),
          enc("route-22", "019", "GRASS", "10%", "3", "UNCOMMON", "019", "020", tip: true),
          enc("route-22", "021", "GRASS", "10%", "2–6", "UNCOMMON", "021", "022", tip: true)
        ],
        trainers: [ tr("RIVAL", "Blue", 280, mon("021", 9), mon("133", 8), sprite: "blue-gen1",
          where: scene_shot("route-22-rival", "WHERE"),
          battle: scene_shot("battle-rival-route-22", "BATTLE")) ],
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
          step(b, 1),
          step(b, 2, shot: map_shot("route-2", 2, "STEP 2"))
        ],
        encounters: [
          enc("route-2", "016", "GRASS", "35%", "3–7", "COMMON", "016", "017", "018", tip: true),
          enc("route-2", "019", "GRASS", "35%", "3–4", "COMMON", "019", "020", tip: true),
          enc("route-2", "029", "GRASS", "15%", "4–6", "UNCOMMON", "029", "030", "031", tip: true),
          enc("route-2", "032", "GRASS", "15%", "4–6", "UNCOMMON", "032", "033", "034", tip: true)
        ],
        trainers: [], oak_queue: [ oak("route-2", "016", 1), oak("route-2", "019", 1) ],
        trades: [ trade("route-2", "mr_mime", "035", "122", "MILES",
          house: "route-2-trade-house", inside: "route-2-trade-house-inside") ]
      )
    end

    def self.viridian_forest
      b = base("viridian-forest")
      Location.new(
        slug: "viridian-forest", kind: "FOREST", name: "Viridian Forest", order: 6, badge: nil,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [
          step(b, 1, items: [ item(b, 1, "Poké Ball", "poke_ball") ],
            shot: map_shot("viridian-forest", 1, "STEP 1")),
          step(b, 2, hidden: [ hidden(b, 2, "Antidote", "antidote", "viridian-forest-antidote", "vf-antidote") ]),
          step(b, 3, items: [ item(b, 3, "Potion", "potion", at: [ 25, 11 ]) ],
            shot: map_shot("viridian-forest", 3, "STEP 3")),
          step(b, 4, hidden: [ hidden(b, 4, "Potion", "potion", "viridian-forest-hidden-potion", "vf-potion") ]),
          step(b, 5, shot: map_shot("viridian-forest", 5, "STEP 5"))
        ],
        encounters: [
          enc("viridian-forest", "010", "GRASS", "50%", "3–6", "COMMON", "010", "011", "012", tip: true),
          enc("viridian-forest", "011", "GRASS", "25%", "4–6", "UNCOMMON", "010", "011", "012", tip: true),
          enc("viridian-forest", "016", "GRASS", "24%", "4–8", "UNCOMMON", "016", "017", "018", tip: true),
          enc("viridian-forest", "017", "GRASS", "1%", "9", "RARE", "016", "017", "018", tip: true)
        ],
        trainers: [],
        oak_queue: [ oak("viridian-forest", "010", 1) ]
      )
    end

    def self.pewter_city
      b = base("pewter-city")
      Location.new(
        slug: "pewter-city", kind: "CITY", name: "Pewter City", order: 7, badge: "BOULDER",
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [
          step(b, 1, shot: map_shot("pewter-city", 1, "STEP 1")),
          step(b, 2)
        ],
        gym_after: 1,
        encounters: [],
        trainers: [],
        gym: gym("pewter-city", "Pewter Gym", "ROCK", "BOULDER", "TM34 · BIDE",
          leader("Brock", 1188, mon("074", 10), mon("095", 12),
            battle: scene_shot("battle-brock", "BATTLE"), opp: [ "BROCK", 1 ])),
        oak_queue: []
      )
    end

    def self.loc(slug, kind, name, order, steps: 3, shots: [], html_steps: [], hidden_items: {}, encounters: [], trainers: [], trades: [], oak_queue: [], badge: nil, gym: nil, gym_after: nil)
      b = base(slug)
      Location.new(
        slug: slug, kind: kind, name: name, order: order, badge: badge,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: (1..steps).map { |i|
          step(b, i, html: html_steps.include?(i),
            shot: shots.include?(i) ? map_shot(slug, i, "STEP #{i}") : nil,
            hidden: hidden_items.fetch(i, []).map { |args| hidden(b, i, *args) })
        },
        encounters: encounters, trainers: trainers, trades: trades, oak_queue: oak_queue,
        gym: gym, gym_after: gym_after
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
      "BUG CATCHER" => "bugcatcher-gen1", "LASS" => "lass-gen1", "YOUNGSTER" => "youngster-gen1",
      "JR. TRAINER♂" => "jrtrainer-gen1", "JR. TRAINER♀" => "jrtrainerf-gen1",
      "BLACK BELT" => "blackbelt-gen1", "TEAM ROCKET" => "rocket-gen1",
      "RIVAL" => "blue-gen1", "CHAMPION" => "blue-gen1champion",
      "SWIMMER" => "swimmer-gen1", "SAILOR" => "sailor-gen1", "ROCKER" => "rocker-gen1",
      "GENTLEMAN" => "gentleman-gen1", "BEAUTY" => "beauty-gen1",
      "COOLTRAINER♂" => "acetrainer-gen1", "COOLTRAINER♀" => "acetrainerf-gen1",
      "JUGGLER" => "juggler-gen1", "TAMER" => "tamer-gen1", "PSYCHIC" => "psychic-gen1",
      "CHANNELER" => "channeler-gen1", "SUPER NERD" => "supernerd-gen1", "BURGLAR" => "burglar-gen1",
      "HIKER" => "hiker-gen1", "BIRD KEEPER" => "birdkeeper-gen1", "BIKER" => "biker-gen1",
      "SCIENTIST" => "scientist-gen1", "FISHERMAN" => "fisherman-gen1", "CUE BALL" => "cueball-gen1",
      "POKéMANIAC" => "pokemaniac-gen1", "GAMBLER" => "gambler-gen1", "ENGINEER" => "engineer-gen1"
    }.freeze

    CLASS_LABELS = {
      "BUG_CATCHER" => "BUG CATCHER", "SUPER_NERD" => "SUPER NERD", "CUE_BALL" => "CUE BALL",
      "BIRD_KEEPER" => "BIRD KEEPER", "JR_TRAINER_M" => "JR. TRAINER♂",
      "JR_TRAINER_F" => "JR. TRAINER♀", "COOLTRAINER_M" => "COOLTRAINER♂",
      "COOLTRAINER_F" => "COOLTRAINER♀", "BLACKBELT" => "BLACK BELT", "ROCKET" => "TEAM ROCKET",
      "PSYCHIC_TR" => "PSYCHIC", "FISHER" => "FISHERMAN", "POKEMANIAC" => "POKéMANIAC"
    }.freeze

    WHERE_LABEL = "WHERE".freeze
    INSIDE_LABEL = "INSIDE".freeze

    def self.class_label(const) = CLASS_LABELS.fetch(const) { const.tr("_", " ") }

    def self.trainer_sprite(cls, name) = (name && NAME_SPRITES[name]) || CLASS_SPRITES.fetch(cls)

    # `opp` is the map object's [OPP_CLASS, party] pair; it resolves the marker letter in
    # attach_maps so the card and its pin agree. Omit it and the card just carries no letter.
    def self.tr(cls, name, reward, *team, sprite: nil, where: nil, battle: nil, opp: nil, tick: nil)
      Trainer.new(cls: cls, name: name, reward: reward, team: team,
        sprite: sprite || trainer_sprite(cls, name), where: where, battle: battle,
        opp: opp && "#{opp[0]}:#{opp[1]}", tick: tick)
    end

    def self.leader(name, reward, *team, battle: nil, opp: nil) = tr("LEADER", name, reward, *team, battle: battle, opp: opp)

    def self.rival(reward, *team, where: nil, battle: nil, opp: nil) = tr("RIVAL", "Blue", reward, *team, sprite: "blue-gen1two", where: where, battle: battle, opp: opp)

    def self.gym(slug, name, type, badge, tm, leader, puzzle: [], trainers: [])
      b = base(slug)
      Gym.new(
        type: type, name: name, intro_key: "#{b}.gym.intro",
        shot: shot("GYM"), badge: badge, badge_img: "walkthrough/yellow/badges/#{badge.downcase}.png",
        tm: tm, puzzle: puzzle, trainers: trainers, leader: leader
      )
    end

    def self.gstep(slug, n, map: false)
      GymStep.new(n: n, text_key: "#{base(slug)}.gym.puzzle.#{n}", shot: map ? shot("STEP #{n}") : nil)
    end

    def self.route_3
      b = base("route-3")
      Location.new(
        slug: "route-3", kind: "ROUTE", name: "Route 3", order: 8, badge: nil,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [ step(b, 1), step(b, 2), step(b, 3, shot: map_shot("route-3", 3, "STEP 3")) ],
        encounters: [
          enc("route-3", "021", "GRASS", "55%", "8–12", "COMMON", "021", "022"),
          enc("route-3", "019", "GRASS", "15%", "10–12", "UNCOMMON", "019", "020"),
          enc("route-3", "027", "GRASS", "15%", "8–10", "UNCOMMON", "027", "028"),
          enc("route-3", "056", "GRASS", "15%", "9", "UNCOMMON", "056", "057")
        ],
        trainers: [],
        oak_queue: [ oak("route-3", "027", 1) ]
      )
    end

    def self.mt_moon
      loc("mt-moon", "CAVE", "Mt. Moon", 9, steps: 4, shots: [ 3, 4 ],
        hidden_items: { 2 => [
          [ "Moon Stone", "moon_stone", "mt-moon-hidden-moon-stone", "mt-moon-moon-stone" ],
          [ "Ether", "ether", "mt-moon-hidden-ether", "mt-moon-ether" ]
        ] },
        encounters: [
          enc("mt-moon", "041", "CAVE", "75%", "6–11", "COMMON", "041", "042"),
          enc("mt-moon", "074", "CAVE", "15%", "8–10", "UNCOMMON", "074", "075", "076"),
          enc("mt-moon", "046", "CAVE", "5%", "8", "RARE", "046", "047"),
          enc("mt-moon", "035", "CAVE", "1%", "11", "RARE", "035", "036", tip: true)
        ],
        trainers: [ tr("TEAM ROCKET", "Jessie & James", 420,
          mon("023", 14), mon("052", 14), mon("109", 14),
          where: scene_shot("mt-moon-jessie-james", "WHERE"),
          battle: scene_shot("battle-mt-moon-jessie-james", "BATTLE")) ],
        oak_queue: [ oak("mt-moon", "035", 1), oak("mt-moon", "074", 1) ])
    end

    def self.route_4
      loc("route-4", "ROUTE", "Route 4", 10, steps: 2, shots: [ 1 ],
        encounters: [
          enc("route-4", "021", "GRASS", "55%", "8–12", "COMMON", "021", "022"),
          enc("route-4", "019", "GRASS", "15%", "10–12", "UNCOMMON", "019", "020"),
          enc("route-4", "027", "GRASS", "15%", "8–10", "UNCOMMON", "027", "028"),
          enc("route-4", "056", "GRASS", "15%", "9", "UNCOMMON", "056", "057")
        ])
    end

    def self.cerulean_city
      loc("cerulean-city", "CITY", "Cerulean City", 11, steps: 2, shots: [ 1, 2 ], gym_after: 1, badge: "CASCADE",
        encounters: [ enc("cerulean-city", "001", "GIFT", "-", "10", "GIFT", "001", "002", "003", tip: true) ],
        trainers: [],
        gym: gym("cerulean-city", "Cerulean Gym", "WATER", "CASCADE", "TM11 · BUBBLEBEAM",
          leader("Misty", 2079, mon("120", 18), mon("121", 21), battle: scene_shot("battle-misty", "BATTLE"), opp: [ "MISTY", 1 ])),
        oak_queue: [ oak("cerulean-city", "001", 1) ])
    end

    def self.route_24
      loc("route-24", "ROUTE", "Route 24", 12, shots: [ 3 ],
        encounters: [
          enc("route-24", "004", "GIFT", "-", "10", "GIFT", "004", "005", "006", tip: true),
          enc("route-24", "043", "GRASS", "30%", "12–14", "COMMON", "043", "044", "045"),
          enc("route-24", "069", "GRASS", "30%", "12–14", "COMMON", "069", "070", "071"),
          enc("route-24", "016", "GRASS", "29%", "13–17", "UNCOMMON", "016", "017", "018"),
          enc("route-24", "048", "GRASS", "10%", "13–16", "UNCOMMON", "048", "049")
        ],
        trainers: [ rival(595, mon("021", 18), mon("027", 15), mon("019", 15), mon("133", 17),
          where: scene_shot("route-24-rival", "WHERE"),
          battle: scene_shot("battle-rival-cerulean", "BATTLE")) ],
        oak_queue: [ oak("route-24", "004", 1), oak("route-24", "043", 1), oak("route-24", "069", 1) ])
    end

    def self.route_25
      loc("route-25", "ROUTE", "Route 25", 13, steps: 2, shots: [ 2 ],
        encounters: [
          enc("route-25", "043", "GRASS", "30%", "12–14", "COMMON", "043", "044", "045"),
          enc("route-25", "069", "GRASS", "30%", "12–14", "COMMON", "069", "070", "071"),
          enc("route-25", "016", "GRASS", "29%", "13–17", "UNCOMMON", "016", "017", "018"),
          enc("route-25", "048", "GRASS", "10%", "13–16", "UNCOMMON", "048", "049")
        ],
        oak_queue: [ oak("route-25", "048", 1) ])
    end

    def self.route_5
      loc("route-5", "ROUTE", "Route 5", 14, steps: 2, shots: [ 2 ],
        encounters: [
          enc("route-5", "016", "GRASS", "40%", "15–17", "COMMON", "016", "017", "018"),
          enc("route-5", "019", "GRASS", "30%", "14–16", "COMMON", "019", "020"),
          enc("route-5", "063", "GRASS", "15%", "7", "UNCOMMON", "063", "064", "065"),
          enc("route-5", "039", "GRASS", "10%", "3–7", "UNCOMMON", "039", "040")
        ],
        trades: [ trade("route-5", "machoke", "104", "067", "RICKY",
          house: "route-5-underground-house", inside: "route-5-underground-house-inside") ],
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
      loc("vermilion-city", "CITY", "Vermilion City", 16, steps: 3, shots: [ 2, 3 ], gym_after: 2, badge: "THUNDER",
        encounters: [ enc("vermilion-city", "007", "GIFT", "-", "10", "GIFT", "007", "008", "009", tip: true) ],
        trainers: [],
        gym: gym("vermilion-city", "Vermilion Gym", "ELECTRIC", "THUNDER", "TM24 · THUNDERBOLT",
          leader("Lt. Surge", 2772, mon("026", 28), battle: scene_shot("battle-lt-surge", "BATTLE"), opp: [ "LT_SURGE", 1 ]),
          puzzle: [ gstep("vermilion-city", 1), gstep("vermilion-city", 2, map: true), gstep("vermilion-city", 3) ]),
        oak_queue: [ oak("vermilion-city", "007", 1) ])
    end

    def self.ss_anne
      loc("ss-anne", "BUILDING", "S.S. Anne", 17, steps: 3, shots: [ 3 ],
        trainers: [ rival(1300, mon("021", 19), mon("019", 16), mon("027", 18), mon("133", 20),
          where: scene_shot("ss-anne-rival", "WHERE"),
          battle: scene_shot("battle-rival-ss-anne", "BATTLE"), opp: [ "RIVAL1", 1 ]) ])
    end

    def self.route_11
      loc("route-11", "ROUTE", "Route 11", 18, steps: 2,
        encounters: [
          enc("route-11", "016", "GRASS", "40%", "16–18", "COMMON", "016", "017", "018"),
          enc("route-11", "019", "GRASS", "25%", "15–17", "UNCOMMON", "019", "020"),
          enc("route-11", "096", "GRASS", "24%", "15–19", "UNCOMMON", "096", "097")
        ],
        trades: [ trade("route-11", "dugtrio", "108", "051", "GURIO",
          house: "route-11-gate", inside: "route-11-gate-inside") ],
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
          rival(1625, mon("022", 25), mon("027", 20), mon("037", 23), mon("081", 22), mon("133", 25),
            where: scene_shot("pokemon-tower-rival", "WHERE"),
            battle: scene_shot("battle-pokemon-tower-rival", "BATTLE")),
          tr("TEAM ROCKET", "Jessie & James", 810,
            mon("052", 27), mon("024", 27), mon("110", 27),
            where: scene_shot("pokemon-tower-jessie-james", "WHERE"),
            battle: scene_shot("battle-pokemon-tower-jessie-james", "BATTLE"))
        ],
        oak_queue: [ oak("pokemon-tower", "092", 1), oak("pokemon-tower", "104", 1) ])
    end

    def self.route_12
      loc("route-12", "ROUTE", "Route 12", 29, steps: 3, shots: [ 1 ],
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
      loc("fuchsia-city", "CITY", "Fuchsia City", 33, steps: 4, gym_after: 1, badge: "SOUL",
        encounters: [
          enc("fuchsia-city", "130", "SUPER ROD", "10%", "15", "UNCOMMON", "129", "130", tip: true)
        ],
        trainers: [],
        gym: gym("fuchsia-city", "Fuchsia Gym", "POISON", "SOUL", "TM06 · TOXIC",
          leader("Koga", 4950, mon("048", 44), mon("048", 46), mon("048", 48), mon("049", 50), battle: scene_shot("battle-koga", "BATTLE"), opp: [ "KOGA", 1 ]),
          puzzle: [ gstep("fuchsia-city", 1), gstep("fuchsia-city", 2, map: true), gstep("fuchsia-city", 3) ]),
        oak_queue: [ oak("fuchsia-city", "130", 1) ])
    end

    def self.safari_zone
      loc("safari-zone", "DUNGEON", "Safari Zone", 34, steps: 4, html_steps: [ 1 ],
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
      loc("route-16", "ROUTE", "Route 16", 35, steps: 3, shots: [ 2 ],
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
        ],
        trades: [ trade("route-18", "parasect", "114", "047", "SPIKE",
          house: "route-18-gate", inside: "route-18-gate-inside") ])
    end

    def self.saffron_city
      loc("saffron-city", "CITY", "Saffron City", 38, steps: 3, gym_after: 2, badge: "MARSH",
        trainers: [ tr("BLACK BELT", nil, 925, mon("106", 37), mon("107", 37),
          where: scene_shot("saffron-dojo-master", "WHERE")) ],
        gym: gym("saffron-city", "Saffron Gym", "PSYCHIC", "MARSH", "TM46 · PSYWAVE",
          leader("Sabrina", 4950, mon("063", 50), mon("064", 50), mon("065", 50), battle: scene_shot("battle-sabrina", "BATTLE"), opp: [ "SABRINA", 1 ]),
          puzzle: [ gstep("saffron-city", 1), gstep("saffron-city", 2, map: true), gstep("saffron-city", 3) ]),
        oak_queue: [ oak("saffron-city", "106", 1) ])
    end

    def self.silph_co
      loc("silph-co", "BUILDING", "Silph Co.", 39, steps: 4,
        encounters: [ enc("silph-co", "131", "GIFT", "-", "15", "GIFT", "131", tip: true) ],
        trainers: [
          rival(2600, mon("022", 37), mon("085", 38), mon("103", 38), mon("133", 40),
            where: scene_shot("silph-co-rival", "WHERE"),
            battle: scene_shot("battle-silph-rival", "BATTLE")),
          tr("TEAM ROCKET", "Giovanni", 4059,
            mon("033", 37), mon("111", 37), mon("053", 35), mon("031", 41),
            where: scene_shot("silph-co-giovanni", "WHERE"),
            battle: scene_shot("battle-silph-giovanni", "BATTLE"), opp: [ "GIOVANNI", 2 ])
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
      loc("seafoam-islands", "CAVE", "Seafoam Islands", 42, steps: 4, shots: [ 3 ],
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
      loc("cinnabar-island", "TOWN", "Cinnabar Island", 44, steps: 3, gym_after: 2, badge: "VOLCANO",
        encounters: [
          enc("cinnabar-island", "138", "FOSSIL", "-", "30", "GIFT", "138", "139", tip: true),
          enc("cinnabar-island", "140", "FOSSIL", "-", "30", "GIFT", "140", "141", tip: true),
          enc("cinnabar-island", "142", "FOSSIL", "-", "30", "GIFT", "142", tip: true),
          enc("cinnabar-island", "072", "SURF", "100%", "5–40", "COMMON", "072", "073"),
          enc("cinnabar-island", "120", "SUPER ROD", "30%", "15–30", "UNCOMMON", "120", "121")
        ],
        trainers: [],
        trades: [
          trade("cinnabar-island", "muk", "115", "089", "STICKY",
            house: "cinnabar-lab", inside: "cinnabar-lab-fossil-inside"),
          trade("cinnabar-island", "rhydon", "055", "112", "BUFFY",
            house: "cinnabar-lab", inside: "cinnabar-lab-trade-buffy"),
          trade("cinnabar-island", "dewgong", "058", "087", "CEZANNE",
            house: "cinnabar-lab", inside: "cinnabar-lab-trade-cezanne")
        ],
        gym: gym("cinnabar-island", "Cinnabar Gym", "FIRE", "VOLCANO", "TM38 · FIRE BLAST",
          leader("Blaine", 5346, mon("038", 48), mon("078", 50), mon("059", 54), battle: scene_shot("battle-blaine", "BATTLE"), opp: [ "BLAINE", 1 ]),
          puzzle: [ gstep("cinnabar-island", 1), gstep("cinnabar-island", 2), gstep("cinnabar-island", 3, map: true) ]),
        oak_queue: [ oak("cinnabar-island", "138", 1), oak("cinnabar-island", "140", 1), oak("cinnabar-island", "142", 1) ])
    end

    def self.pokemon_mansion
      loc("pokemon-mansion", "BUILDING", "Pokémon Mansion", 45, steps: 3,
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
      loc("viridian-gym", "GYM", "Viridian Gym", 47, steps: 2, gym_after: 1, badge: "EARTH",
        gym: gym("viridian-gym", "Viridian Gym", "GROUND", "EARTH", "TM27 · FISSURE",
          leader("Giovanni", 5445, mon("051", 50), mon("053", 53), mon("031", 53), mon("034", 55), mon("112", 55), battle: scene_shot("battle-giovanni-viridian", "BATTLE"), opp: [ "GIOVANNI", 3 ]),
          puzzle: [ gstep("viridian-gym", 1), gstep("viridian-gym", 2), gstep("viridian-gym", 3, map: true) ]))
    end

    def self.victory_road
      loc("victory-road", "CAVE", "Victory Road", 48, steps: 4, shots: [ 3 ],
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
      loc("route-23", "ROUTE", "Route 23", 49, steps: 3,
        encounters: [
          enc("route-23", "132", "GRASS", "35%", "33–43", "COMMON", "132"),
          enc("route-23", "056", "GRASS", "20%", "36–41", "UNCOMMON", "056", "057"),
          enc("route-23", "022", "GRASS", "15%", "40–45", "UNCOMMON", "021", "022"),
          enc("route-23", "024", "GRASS", "5%", "41", "RARE", "023", "024")
        ])
    end

    def self.indigo_plateau
      loc("indigo-plateau", "BUILDING", "Indigo Plateau", 50, steps: 3,
        trainers: [
          tr("ELITE FOUR", "Lorelei", 5544,
            mon("087", 54), mon("091", 53), mon("080", 54), mon("124", 56), mon("131", 56),
            where: scene_shot("indigo-lorelei", "WHERE"), battle: scene_shot("battle-lorelei", "BATTLE")),
          tr("ELITE FOUR", "Bruno", 5742,
            mon("095", 53), mon("107", 55), mon("106", 55), mon("095", 56), mon("068", 58),
            where: scene_shot("indigo-bruno", "WHERE"), battle: scene_shot("battle-bruno", "BATTLE")),
          tr("ELITE FOUR", "Agatha", 5940,
            mon("094", 56), mon("042", 56), mon("093", 55), mon("024", 58), mon("094", 60),
            where: scene_shot("indigo-agatha", "WHERE"), battle: scene_shot("battle-agatha", "BATTLE")),
          tr("ELITE FOUR", "Lance", 6138,
            mon("130", 58), mon("148", 56), mon("148", 56), mon("142", 60), mon("149", 62),
            where: scene_shot("indigo-lance", "WHERE"), battle: scene_shot("battle-lance", "BATTLE")),
          tr("CHAMPION", "Blue", 6435,
            mon("028", 61), mon("065", 59), mon("103", 61), mon("091", 61), mon("038", 63), mon("135", 65),
            where: scene_shot("indigo-champion", "WHERE"), battle: scene_shot("battle-champion", "BATTLE"))
        ])
    end

    def self.cerulean_cave
      loc("cerulean-cave", "CAVE", "Cerulean Cave", 51, steps: 4, shots: [ 4 ],
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
      loc("route-10", "ROUTE", "Route 10", 21, steps: 3, shots: [ 1 ],
        encounters: [
          enc("route-10", "081", "GRASS", "50%", "16–22", "COMMON", "081", "082"),
          enc("route-10", "019", "GRASS", "20%", "18", "UNCOMMON", "019", "020"),
          enc("route-10", "032", "GRASS", "10%", "17", "UNCOMMON", "032", "033", "034"),
          enc("route-10", "066", "GRASS", "5%", "16–18", "RARE", "066", "067", "068")
        ],
        oak_queue: [ oak("route-10", "081", 1) ])
    end

    def self.rock_tunnel
      loc("rock-tunnel", "CAVE", "Rock Tunnel", 22, steps: 3, shots: [ 1 ],
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
      loc("celadon-city", "CITY", "Celadon City", 26, steps: 3, gym_after: 2, badge: "RAINBOW",
        encounters: [
          enc("celadon-city", "133", "GIFT", "-", "25", "GIFT", "133", tip: true),
          enc("celadon-city", "137", "GAME CORNER", "9999", "26", "GIFT", "137", tip: true),
          enc("celadon-city", "037", "GAME CORNER", "1000", "18", "GIFT", "037", "038", tip: true)
        ],
        trainers: [],
        gym: gym("celadon-city", "Celadon Gym", "GRASS", "RAINBOW", "TM21 · MEGA DRAIN",
          leader("Erika", 3168, mon("114", 30), mon("070", 32), mon("044", 32), battle: scene_shot("battle-erika", "BATTLE"), opp: [ "ERIKA", 1 ])),
        oak_queue: [ oak("celadon-city", "133", 1), oak("celadon-city", "137", 1) ])
    end

    def self.rocket_hideout
      loc("rocket-hideout", "DUNGEON", "Rocket Hideout", 27, steps: 4,
        trainers: [
          tr("TEAM ROCKET", "Jessie & James", 750,
            mon("109", 25), mon("052", 25), mon("023", 25),
            where: scene_shot("rocket-hideout-jessie-james", "WHERE"),
            battle: scene_shot("battle-rocket-hideout-jessie-james", "BATTLE")),
          tr("TEAM ROCKET", "Giovanni", 2871,
            mon("095", 25), mon("111", 24), mon("053", 29),
            where: scene_shot("rocket-hideout-giovanni", "WHERE"),
            battle: scene_shot("battle-rocket-hideout-giovanni", "BATTLE"), opp: [ "GIOVANNI", 1 ])
        ])
    end

    def self.power_plant
      loc("power-plant", "BUILDING", "Power Plant", 43, steps: 3, shots: [ 3 ],
        encounters: [
          enc("power-plant", "100", "FLOORS", "40%", "21–33", "COMMON", "100", "101"),
          enc("power-plant", "081", "FLOORS", "25%", "20–33", "COMMON", "081", "082"),
          enc("power-plant", "088", "FLOORS", "15%", "23–33", "UNCOMMON", "088", "089"),
          enc("power-plant", "101", "FLOORS", "10%", "24–33", "UNCOMMON", "100", "101"),
          enc("power-plant", "082", "FLOORS", "5%", "21–33", "RARE", "081", "082"),
          enc("power-plant", "089", "FLOORS", "5%", "33", "RARE", "088", "089"),
          enc("power-plant", "145", "STATIC", "-", "50", "STATIC", "145", tip: true)
        ],
        oak_queue: [ oak("power-plant", "145", 1), oak("power-plant", "100", 1) ])
    end

    def self.route_21
      loc("route-21", "ROUTE", "Route 21", 46, steps: 2,
        encounters: [
          enc("route-21", "016", "GRASS", "35%", "21–23", "COMMON", "016", "017", "018"),
          enc("route-21", "019", "GRASS", "35%", "21–23", "COMMON", "019", "020"),
          enc("route-21", "017", "GRASS", "15%", "25–29", "UNCOMMON", "016", "017", "018"),
          enc("route-21", "020", "GRASS", "15%", "25–29", "UNCOMMON", "019", "020"),
          enc("route-21", "072", "SURF", "100%", "5–40", "COMMON", "072", "073"),
          enc("route-21", "129", "SUPER ROD", "40%", "15–25", "COMMON", "129", "130", tip: true),
          enc("route-21", "118", "SUPER ROD", "25%", "15–25", "UNCOMMON", "118", "119", tip: true),
          enc("route-21", "090", "SUPER ROD", "20%", "15–25", "UNCOMMON", "090", "091"),
          enc("route-21", "120", "SUPER ROD", "15%", "15–25", "UNCOMMON", "120", "121")
        ],
        oak_queue: [ oak("route-21", "129", 1), oak("route-21", "118", 1) ])
    end

    def self.step(base, n, items: [], hidden: [], shot: nil, html: false, link: nil)
      Step.new(n: n, title_key: "#{base}.steps.#{n}.title",
        text_key: "#{base}.steps.#{n}.#{html ? 'text_html' : 'text'}",
        items: items, hidden: hidden, shot: shot, link: link)
    end

    ITEM_SPRITES = { "TM34 Bide" => "tm-normal", "Oak's Parcel" => "oaks-parcel", "TM42 Dream Eater" => "tm-psychic" }.freeze

    def self.item_sprite(name)
      ITEM_SPRITES.fetch(name) { name.downcase.gsub("é", "e").gsub(/[^a-z0-9]+/, "-") }
    end

    def self.item(base, n, name, key, at: nil)
      Item.new(name: name, where_key: "#{base}.steps.#{n}.items.#{key}",
        sprite: item_sprite(name), at: at)
    end

    def self.hidden(base, n, name, key, scene, pin, at: nil)
      HiddenItem.new(name: name, where_key: "#{base}.steps.#{n}.hidden.#{key}",
        image: scenes.dig(scene, "image"), pin: pin, sprite: item_sprite(name), at: at)
    end

    def self.later(base, key, name, kind, need, scene, pin = nil)
      LaterItem.new(name: name, sprite: item_sprite(name), kind: kind, need: need,
        where_key: "#{base}.later.#{key}.where", after_key: "#{base}.later.#{key}.after",
        image: scenes.dig(scene, "image"), pin: pin)
    end

    TRIVIA_MARKS = { "yes" => "✓", "no" => "✕", "na" => "–" }.freeze

    def self.trivia(base, anchor:, cards:)
      Trivia.new(anchor: anchor, title_key: "#{base}.trivia.title", intro_key: "#{base}.trivia.intro",
        note_key: "#{base}.trivia.note", cards: cards)
    end

    def self.missable(base, anchor:, after_step:)
      Missable.new(anchor: anchor, title_key: "#{base}.missable.title",
        body_key: "#{base}.missable.body_html", tip_key: "#{base}.missable.tip", after_step: after_step)
    end

    def self.trivia_card(base, key, dex, tone, this_state, rt22_state)
      rows = { "this" => this_state, "rt22" => rt22_state }.map do |slot, state|
        { state: state, mark: TRIVIA_MARKS.fetch(state), text_key: "#{base}.trivia.cards.#{key}.#{slot}" }
      end
      TriviaCard.new(dex: dex, name: NAMES.fetch(dex), tone: tone, rows: rows)
    end

    def self.shot(label) = Shot.new(image: nil, label: label)
  end
end
