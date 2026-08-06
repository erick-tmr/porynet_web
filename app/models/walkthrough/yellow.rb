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

    # `from: true` adds the gift-source badge; `unlock:` is the icon (an R2 path) a gift's unlock
    # condition shows, or nil for an unconditional gift.
    def self.enc(slug, dex, how, rate, level, rarity, *chain, tip: false, from: false, unlock: nil)
      b = base(slug)
      key = mon_key(dex)
      Encounter.new(dex: dex, name: NAMES.fetch(dex), how: how, rate: rate, level: level,
        rarity: rarity, tip_key: (tip ? "#{b}.tips.#{key}" : nil), evo_line: line(*chain),
        from_key: (from ? "#{b}.gifts.#{key}.from" : nil),
        unlock_key: (unlock ? "#{b}.gifts.#{key}.unlock" : nil), unlock_icon: unlock)
    end

    # Verbatim from HappinessChangeTable in engine/events/pikachu_happiness.asm: each action's
    # friendship change at current value bands 0-99 / 100-199 / 200-255.
    FRIENDSHIP_TABLE = [
      [ "levelup", [ 5, 3, 2 ] ], [ "hp_item", [ 5, 3, 2 ] ], [ "x_item", [ 1, 1, 0 ] ],
      [ "gym_leader", [ 3, 2, 1 ] ], [ "tm_hm", [ 1, 1, 0 ] ], [ "walking", [ 2, 1, 1 ] ],
      [ "deposit", [ -3, -3, -5 ] ], [ "faint", [ -1, -1, -1 ] ], [ "poison_faint", [ -5, -5, -10 ] ],
      [ "careless", [ -5, -5, -10 ] ], [ "trade", [ -10, -10, -20 ] ]
    ].freeze

    def self.pikachu_friendship
      b = "#{K}.pikachu_friendship"
      PikachuFriendship.new(start: 90, threshold: 147, max: 255,
        rows: FRIENDSHIP_TABLE.map { |key, values| FriendshipRow.new("#{b}.rows.#{key}", values) })
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
      { slug: "leg-03", special: false, locs: %w[pewter-city route-3 route-4-mt-moon] },
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
      { slug: "silph-co", special: true, locs: %w[silph-co] },
      { slug: "leg-10", special: false, locs: %w[route-16 route-17 route-18 saffron-city] },
      { slug: "leg-11", special: false, locs: %w[route-19 route-20] },
      { slug: "seafoam-islands", special: true, locs: %w[seafoam-islands] },
      { slug: "power-plant", special: true, locs: %w[power-plant] },
      { slug: "leg-12", special: false, locs: %w[cinnabar-island pokemon-mansion route-21] },
      { slug: "leg-13", special: false, locs: %w[viridian-gym] },
      { slug: "victory-road", special: true, locs: %w[victory-road] },
      { slug: "leg-14", special: false, locs: %w[route-23] },
      { slug: "indigo-plateau", special: true, locs: %w[indigo-plateau] },
      { slug: "cerulean-cave", special: true, locs: %w[cerulean-cave] }
    ].freeze

    OAK_EXAMPLE = [
      [ "025", "START" ], [ "010", "CATCH" ], [ "011", "EITHER" ], [ "012", "EVOLVE" ],
      [ "016", "CATCH" ], [ "017", "EITHER" ], [ "018", "EVOLVE" ], [ "019", "CATCH" ],
      [ "020", "EVOLVE" ], [ "021", "CATCH" ], [ "022", "EVOLVE" ], [ "029", "CATCH" ],
      [ "030", "EVOLVE" ], [ "032", "CATCH" ], [ "033", "EVOLVE" ], [ "056", "CATCH" ],
      [ "057", "EVOLVE" ]
    ].freeze

    MODE_SOURCES = {
      "living" => "https://bulbapedia.bulbagarden.net/wiki/Living_Pok%C3%A9dex",
      "oak" => "https://bulbagarden.net/threads/challenge-run-encyclopedia.307749/"
    }.freeze

    def self.game
      locations = all_locations
      by_slug = locations.to_h { |loc| [ loc.slug, loc ] }
      legs = build_legs(by_slug)
      Game.new(
        slug: "yellow",
        name: "Pokémon Yellow",
        region: "Kanto",
        dex_goal: 151,
        oak_example: OAK_EXAMPLE.map { |dex, how| OakExample.new(dex: dex, name: NAMES.fetch(dex), how: how) },
        locations: locations,
        legs: legs,
        best_catches: compute_best_catches(locations),
        windows: Challenge.windows(legs)
      )
    end

    MEW_GLITCH_K = "#{K}.mew_glitch".freeze

    # The Cerulean Mew-glitch guide. Trainer identities and the level formula here are verified
    # against the pokeyellow disassembly (Swimmer #1 = Lv16 Horsea/Shellder, the trigger is the
    # Jr. Trainer in the grass west of Nugget Bridge, the second-Mew setter is the lone-Slowpoke
    # Youngster on Route 25, and an untouched opponent's neutral Attack stage 7 gives a Lv 7 Mew).
    def self.mew_glitch
      MewGlitch.new(
        facts: mew_facts, tldr: mew_tldr, untouched: mew_untouched, packlist: mew_packlist,
        sleepers: mew_sleepers, phases: mew_phases, second: mew_second,
        stages: mew_stages, baseline: 7, vc_ot: "GF", vc_tid: "22796"
      )
    end

    def self.mew_facts
      b = "#{MEW_GLITCH_K}.facts"
      %w[where earliest level risk].zip(%w[cyan cyan magenta gold]).map do |key, tone|
        MewFact.new("#{b}.#{key}.label", "#{b}.#{key}.value", tone)
      end
    end

    def self.mew_tldr
      tones = %w[setup setup glitch glitch catch]
      (1..5).map { |n| MewTldr.new(n, "#{MEW_GLITCH_K}.tldr.#{n}.title", "#{MEW_GLITCH_K}.tldr.#{n}.text", tones[n - 1]) }
    end

    def self.mew_untouched
      [ [ "trigger", "JR. TRAINER♂", "pink", "RT 24", "route-24-trainer-5-20" ],
        [ "swimmer", "SWIMMER", "cyan", "GYM", "cerulean-city-gym-trainer-8-7" ],
        [ "misty", "Misty", "cyan", "GYM", "cerulean-city-gym-trainer-4-2" ],
        [ "youngster", "YOUNGSTER", "purple", "RT 25", "route-25-trainer-18-5" ] ].map do |key, id, tone, tag, scene|
        b = "#{MEW_GLITCH_K}.untouched.#{key}"
        MewTrainer.new("#{b}.name", "#{b}.where", "#{b}.role", tone,
          NAME_SPRITES[id] || CLASS_SPRITES.fetch(id), tag, "walkthrough/yellow/scenes/#{scene}.png")
      end
    end

    def self.mew_packlist
      b = "#{MEW_GLITCH_K}.pack"
      [ MewPackItem.new(dex: "063", name_key: "#{b}.abra.name", note_key: "#{b}.abra.note"),
        MewPackItem.new(glyph: "x20", name_key: "#{b}.balls.name", note_key: "#{b}.balls.note") ]
    end

    def self.mew_sleepers
      { "012" => "sleep_powder", "035" => "sing", "039" => "sing",
        "043" => "sleep_powder", "069" => "sleep_powder" }.map do |dex, move|
        MewSleeper.new(dex, NAMES.fetch(dex), "#{MEW_GLITCH_K}.moves.#{move}")
      end
    end

    MEW_PHASE_DEFS = [
      { key: "setup", tone: "cyan", steps: [
        { key: "route24", shot: "SETUP 1", scene: "mew-glitch-route24" },
        { key: "bridge", tag: "danger", note: true, shot: "SETUP 2", scene: "mew-glitch-bridge" },
        { key: "youngster", tag: "purple", note: true, shot: "SETUP 3",
          image: "walkthrough/yellow/scenes/route-25-trainer-18-5.png" },
        { key: "abra", tag: "info", note: true, shot: "SETUP 4", scene: "mew-glitch-abra" }
      ] },
      { key: "glitch", tone: "pink", steps: [
        { key: "center", shot: "GLITCH 1", scene: "mew-glitch-center" },
        { key: "lineup", note: true, shot: "GLITCH 2", scene: "mew-glitch-lineup" },
        { key: "start", tag: "info", shot: "GLITCH 3", scene: "mew-glitch-start" },
        { key: "teleport", note: true, shot: "GLITCH 4", scene: "mew-glitch-teleport" },
        { key: "swimmer", tag: "danger", note: true, shot: "GLITCH 5", scene: "mew-glitch-swimmer" }
      ] },
      { key: "catch", tone: "gold", steps: [
        { key: "return", tag: "caution", shot: "CATCH 1", scene: "mew-glitch-return" },
        { key: "encounter" },
        { key: "catch", note: true }
      ] }
    ].freeze

    def self.mew_phases = MEW_PHASE_DEFS.map { |p| mew_phase(p) }

    def self.mew_phase(phase)
      b = "#{MEW_GLITCH_K}.phases.#{phase[:key]}"
      MewPhase.new("#{b}.label", "#{b}.title", "#{b}.meta", phase[:tone],
        phase[:steps].each_with_index.map { |step, i| mew_step(b, step, i + 1) })
    end

    def self.mew_step(phase_base, step, n)
      b = "#{phase_base}.steps.#{step[:key]}"
      MewStep.new(n: n, title_key: "#{b}.title", text_key: "#{b}.text",
        tag_key: (step[:tag] && "#{b}.tag"), tag_tone: step[:tag],
        note_key: (step[:note] && "#{b}.note"), note_label_key: (step[:note] && "#{b}.note_label"),
        shot: mew_step_shot(step))
    end

    # A step frames its shot either from a generated scene (by manifest key) or, for the
    # second-Mew heads-up, by reusing a Trainer WHERE frame already in R2 (the Route 25 Youngster).
    def self.mew_step_shot(step)
      return Shot.new(image: step[:image], label: step[:shot]) if step[:image]

      step[:scene] && scene_shot(step[:scene], step[:shot])
    end

    def self.mew_second
      (1..6).map { |n| MewSecondStep.new(n, "#{MEW_GLITCH_K}.second.#{n}.title", "#{MEW_GLITCH_K}.second.#{n}.text") }
    end

    # The four Trainers to leave standing for the Mew glitch. Each `map`/`marker` is the game's own
    # tickable pin (verified against the manifest), so a card here and its map pin flip together;
    # `key` mirrors that pin's letter so the section and the annotated map read the same. Its WHERE
    # frame is the generator's per-Trainer scene, whose name is `<map>-<marker>` by construction.
    MEW_SPARE_DEFS = [
      { id: "grass-jr", cls: "JR. TRAINER♂", tag: "RT 24", map: "route-24", marker: "trainer-5-20", key: "B" },
      { id: "swimmer", cls: "SWIMMER", tag: "GYM", map: "cerulean-city-gym", marker: "trainer-8-7", key: "C" },
      { id: "misty", cls: "LEADER", tag: "GYM", map: "cerulean-city-gym", marker: "trainer-4-2", key: "A" },
      { id: "slowpoke", cls: "YOUNGSTER", tag: "RT 25", map: "route-25", marker: "trainer-18-5", key: "B" }
    ].freeze

    def self.mew_spares
      b = "#{MEW_GLITCH_K}.spares.trainers"
      MEW_SPARE_DEFS.map do |d|
        image = "walkthrough/yellow/scenes/#{d[:map]}-#{d[:marker]}.png"
        MewSpare.new(id: d[:id], cls: d[:cls], name_key: "#{b}.#{d[:id]}.name",
          role_key: "#{b}.#{d[:id]}.role", where_key: "#{b}.#{d[:id]}.where", tag: d[:tag],
          map: d[:map], marker: d[:marker], key: d[:key],
          shot: Shot.new(image: image, label: WHERE_LABEL))
      end
    end

    def self.mew_stages
      (-6..6).map do |stage|
        level = stage + 7
        kind = mew_stage_kind(stage, level)
        MewStage.new(stage: stage, level: level, n: stage.abs, kind: kind,
          label: (stage.positive? ? "+#{stage}" : stage.to_s))
      end
    end

    def self.mew_stage_kind(stage, level)
      return "untouched" if stage.zero?
      return "raised" if stage.positive?

      level == 1 ? "growl_underflow" : "growl"
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
      locs = [
        pallet_town, route_1, viridian_city, route_22, route_2, viridian_forest, pewter_city,
        route_3, route_4_mt_moon, mt_moon, route_4, cerulean_city, route_24, route_25,
        route_5, route_6, vermilion_city, ss_anne, route_11, digletts_cave,
        route_9, route_10, rock_tunnel, lavender_town, route_8, route_7, celadon_city, rocket_hideout,
        pokemon_tower, route_12, route_13, route_14, route_15, fuchsia_city, safari_zone,
        route_16, route_17, route_18, silph_co, saffron_city, route_19, route_20, seafoam_islands,
        power_plant, cinnabar_island, pokemon_mansion, route_21, viridian_gym, victory_road, route_23,
        indigo_plateau, cerulean_cave
      ].map { |loc| attach_mart(attach_maps(loc, data.fetch(loc.slug, []))) }
      show_mt_moon_approach(locs)
    end

    # The leg-3 approach section has no map data of its own; it borrows Route 4's map so the same
    # interactive map (markers, tick state) shows on both the approach (leg 3) and the east half
    # (leg 4).
    def self.show_mt_moon_approach(locs)
      route_4_maps = locs.find { |loc| loc.slug == "route-4" }.area_maps
      locs.map do |loc|
        loc.slug == "route-4-mt-moon" ? loc.with(area_maps: route_4_maps) : loc
      end
    end

    # The gym's own map belongs in the gym section, not the location header, so pull the "Gym"
    # floor out of the header maps and hand it to the gym as its shot.
    def self.attach_maps(loc, maps)
      gym_map = maps.find { |m| m.floor == "Gym" }
      header = maps.reject { |m| m.floor == "Gym" }
      loc = apply_trainer_notes(tick_items(merge_trainers(loc), header))
      return loc.with(area_maps: header) unless loc.gym && gym_map

      loc.with(area_maps: header,
        gym: loc.gym.with(area: gym_map,
                          shot: Shot.new(image: gym_map.image, label: loc.gym.shot.label)))
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

    # Curated captions stamped onto specific trainers by their OPP_CLASS:party id, keyed by
    # location. Cerulean's Swimmer and Misty carry the Mew-glitch warnings; Route 4's east-plateau
    # Lass carries an "unreachable on the way down" heads-up.
    def self.trainer_notes(slug)
      b = base(slug)
      case slug
      when "cerulean-city"
        { "SWIMMER:1" => "#{b}.gym.notes.swimmer", "MISTY:1" => "#{b}.gym.notes.misty" }
      when "route-4"
        { "LASS:4" => "#{b}.trainers.lass.note" }
      else
        {}
      end
    end

    def self.apply_trainer_notes(loc)
      notes = trainer_notes(loc.slug)
      return loc if notes.empty?

      loc = loc.with(trainers: loc.trainers.map { |t| note_trainer(t, notes) })
      return loc if loc.gym.nil?

      gym = loc.gym
      loc.with(gym: gym.with(trainers: gym.trainers.map { |t| note_trainer(t, notes) },
        leader: note_trainer(gym.leader, notes)))
    end

    def self.note_trainer(trainer, notes)
      key = notes[trainer.opp]
      key ? trainer.with(note_key: key) : trainer
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

    # Price + sprite-picking facts for every shop item, generated alongside the place facts and
    # keyed by the display name a mart's stock uses, so a stock line joins straight onto it.
    def self.item_catalog
      @item_catalog ||= JSON.parse(File.read(File.join(__dir__, "yellow_places.json")))
        .fetch("items").freeze
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
        steps: build_steps(b, [
          { item: [ "Oak's Parcel", "oaks_parcel" ] },
          { item: [ "Pokédex", "pokedex" ] },
          { item: [ "Town Map", "town_map" ] },
          {},
          {},
          { hidden: [ "Potion", "potion", "viridian-city-hidden-potion", "viridian-city-potion" ] },
          {}
        ]),
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
        steps: build_steps(b, [
          {},
          {}
        ]),
        encounters: [
          enc("route-2", "016", "GRASS", "35%", "3–7", "COMMON", "016", "017", "018", tip: true),
          enc("route-2", "019", "GRASS", "35%", "3–4", "COMMON", "019", "020", tip: true),
          enc("route-2", "029", "GRASS", "15%", "4–6", "UNCOMMON", "029", "030", "031", tip: true),
          enc("route-2", "032", "GRASS", "15%", "4–6", "UNCOMMON", "032", "033", "034", tip: true)
        ],
        trainers: [], oak_queue: [ oak("route-2", "016", 1), oak("route-2", "019", 1) ],
        trades: [ trade("route-2", "mr_mime", "035", "122", "MILES",
          house: "route-2-trade-house", inside: "route-2-trade-house-inside") ],
        later: [
          later(b, "moon_stone", "Moon Stone", "ITEM", "Cut", "route-2-moon-stone"),
          later(b, "hp_up", "HP Up", "ITEM", "Cut", "route-2-hp-up"),
          later(b, "flash", "HM05 Flash", "HM", "Cut · 10 caught", "route-2-flash")
        ]
      )
    end

    def self.viridian_forest
      b = base("viridian-forest")
      Location.new(
        slug: "viridian-forest", kind: "FOREST", name: "Viridian Forest", order: 6, badge: nil,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: build_steps(b, [
          {},
          { hidden: [ "Antidote", "antidote", "viridian-forest-hidden-antidote", "viridian-forest-antidote" ] },
          { item: [ "Poké Ball", "pok-ball" ], scene: "viridian-forest-item-pok-ball" },
          { item: [ "Potion", "potion-12-29" ], scene: "viridian-forest-item-potion-12-29", at: [ 12, 29 ] },
          { item: [ "Potion", "potion-25-11" ], scene: "viridian-forest-item-potion-25-11", at: [ 25, 11 ] },
          { hidden: [ "Potion", "potion", "viridian-forest-hidden-potion", "viridian-forest-potion" ] },
          {}
        ]),
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
        oak_queue: [],
        trivia: trivia(b, anchor: "pewter-jigglypuff", shot: scene_shot("pewter-jigglypuff", "PIKACHU"))
      )
    end

    def self.loc(slug, kind, name, order, steps: 3, shots: [], html_steps: [], hidden_items: {}, key_items: {}, encounters: [], trainers: [], trades: [], oak_queue: [], badge: nil, gym: nil, gym_after: nil, gym_finale: false, trivia: nil)
      b = base(slug)
      Location.new(
        slug: slug, kind: kind, name: name, order: order, badge: badge,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: steps.is_a?(Array) ? build_steps(b, steps) : (1..steps).map { |i|
          step(b, i, html: html_steps.include?(i),
            shot: shots.include?(i) ? map_shot(slug, i, "STEP #{i}") : nil,
            items: key_items.fetch(i, []).map { |name, key| item(b, i, name, key) },
            hidden: hidden_items.fetch(i, []).map { |args| hidden(b, i, *args) })
        },
        encounters: encounters, trainers: trainers, trades: trades, oak_queue: oak_queue,
        gym: gym, gym_after: gym_after, gym_finale: gym_finale, trivia: trivia
      )
    end

    # Declarative per-item steps: each def is a narrative beat ({}), a visible overworld item
    # ({ item: [name, key], scene:, at: }) whose GB-screen shot names the ball, one or more key
    # items handed over together ({ items: [[name, key], ...] }), or a hidden item
    # ({ hidden: [name, key, scene, pin], at: }) whose found-frame panel carries its own shot.
    def self.build_steps(base, defs)
      defs.each_with_index.map do |d, i|
        n = i + 1
        step(base, n,
          items: step_items(base, n, d),
          hidden: (d[:hidden] ? [ hidden(base, n, *d[:hidden], at: d[:at]) ] : []),
          shot: (d[:scene] ? scene_shot(d[:scene], "STEP #{n}") : nil))
      end
    end

    def self.step_items(base, n, def_)
      return [ item(base, n, *def_[:item], at: def_[:at]) ] if def_[:item]

      (def_[:items] || []).map { |name, key| item(base, n, name, key) }
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
        steps: [ step(b, 1), step(b, 2) ],
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

    # Route 4 wraps around Mt. Moon: its west sliver (the Mt. Moon Poke Center and cave mouth) is
    # walked at the end of leg 3, and its east half (items, then Cerulean) after the cave in leg 4.
    # This is the leg-3 approach section, sharing Route 4's map; the Magikarp salesman trivia lives
    # here because the Poke Center is on this side.
    def self.route_4_mt_moon
      loc("route-4-mt-moon", "ROUTE", "Route 4", 10, steps: 2, shots: [ 2 ],
        trivia: trivia(base("route-4-mt-moon"), anchor: "mt-moon-magikarp", yellow_only: false,
          shot: scene_shot("mt-moon-magikarp", "MAGIKARP")))
    end

    def self.mt_moon
      loc("mt-moon", "CAVE", "Mt. Moon", 9, steps: [
          {},
          { item: [ "Potion", "potion-20-33" ], scene: "mt-moon-item-potion-20-33", at: [ 20, 33 ] },
          { item: [ "Rare Candy", "rare-candy" ], scene: "mt-moon-item-rare-candy" },
          { item: [ "Escape Rope", "escape-rope" ], scene: "mt-moon-item-escape-rope" },
          { item: [ "TM Water Gun", "tm-water-gun" ], scene: "mt-moon-item-tm-water-gun" },
          { item: [ "Potion", "potion-2-20" ], scene: "mt-moon-item-potion-2-20", at: [ 2, 20 ] },
          { item: [ "Moon Stone", "moon-stone" ], scene: "mt-moon-item-moon-stone" },
          {},
          { item: [ "HP Up", "hp-up" ], scene: "mt-moon-item-hp-up" },
          { hidden: [ "Moon Stone", "moon-stone", "mt-moon-hidden-moon-stone", "mt-moon-moon-stone" ] },
          { item: [ "TM Mega Punch", "tm-mega-punch" ], scene: "mt-moon-item-tm-mega-punch" },
          { hidden: [ "Ether", "ether", "mt-moon-hidden-ether", "mt-moon-ether" ] },
          { items: [ [ "Fossil", "fossil" ] ] },
          {}
        ],
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
      loc("route-4", "ROUTE", "Route 4", 10,
        steps: [
          {},
          { hidden: [ "Great Ball", "great-ball", "route-4-hidden-great-ball", "route-4-great-ball" ] },
          { item: [ "TM Whirlwind", "tm-whirlwind" ], scene: "route-4-item-tm-whirlwind" },
          {}
        ],
        encounters: [
          enc("route-4", "021", "GRASS", "55%", "8–12", "COMMON", "021", "022"),
          enc("route-4", "019", "GRASS", "15%", "10–12", "UNCOMMON", "019", "020"),
          enc("route-4", "027", "GRASS", "15%", "8–10", "UNCOMMON", "027", "028"),
          enc("route-4", "056", "GRASS", "15%", "9", "UNCOMMON", "056", "057")
        ])
    end

    def self.cerulean_city
      loc("cerulean-city", "CITY", "Cerulean City", 11, steps: 4, shots: [ 3, 4 ], gym_after: 3, gym_finale: true, badge: "CASCADE",
        hidden_items: { 2 => [ [ "Rare Candy", "rare_candy", "cerulean-city-hidden-rare-candy", "cerulean-rare-candy" ] ] },
        key_items: { 3 => [ [ "Bicycle", "bicycle" ] ] },
        encounters: [ enc("cerulean-city", "001", "GIFT", "-", "10", "GIFT", "001", "002", "003", tip: true, from: true, unlock: "pokemon/yellow/025.png") ],
        trainers: [],
        gym: gym("cerulean-city", "Cerulean Gym", "WATER", "CASCADE", "TM11 · BUBBLEBEAM",
          leader("Misty", 2079, mon("120", 18), mon("121", 21), battle: scene_shot("battle-misty", "BATTLE"), opp: [ "MISTY", 1 ])),
        oak_queue: [ oak("cerulean-city", "001", 1) ])
    end

    def self.route_24
      loc("route-24", "ROUTE", "Route 24", 12, steps: [
          {},
          {},
          {},
          { item: [ "TM Thunder Wave", "tm-thunder-wave" ], scene: "route-24-item-tm-thunder-wave" },
          {}
        ],
        encounters: [
          enc("route-24", "004", "GIFT", "-", "10", "GIFT", "004", "005", "006", tip: true, from: true),
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
      loc("route-25", "ROUTE", "Route 25", 13, steps: [
          {},
          { hidden: [ "Elixir", "elixir", "route-25-hidden-elixir", "route-25-elixir" ] },
          { item: [ "TM Seismic Toss", "tm-seismic-toss" ], scene: "route-25-item-tm-seismic-toss" },
          { hidden: [ "Ether", "ether", "route-25-hidden-ether", "route-25-ether" ] },
          { item: [ "S.S. Ticket", "s_s_ticket" ] }
        ],
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
      loc("vermilion-city", "CITY", "Vermilion City", 16, steps: [
          { items: [ [ "Bike Voucher", "bike_voucher" ], [ "Old Rod", "old_rod" ] ] },
          { hidden: [ "Max Ether", "max-ether", "vermilion-city-hidden-max-ether", "vermilion-city-max-ether" ] },
          {},
          {}
        ], gym_after: 2, badge: "THUNDER",
        encounters: [ enc("vermilion-city", "007", "GIFT", "-", "10", "GIFT", "007", "008", "009", tip: true, from: true, unlock: "walkthrough/yellow/badges/thunder.png") ],
        trainers: [],
        gym: gym("vermilion-city", "Vermilion Gym", "ELECTRIC", "THUNDER", "TM24 · THUNDERBOLT",
          leader("Lt. Surge", 2772, mon("026", 28), battle: scene_shot("battle-lt-surge", "BATTLE"), opp: [ "LT_SURGE", 1 ]),
          puzzle: [ gstep("vermilion-city", 1), gstep("vermilion-city", 2, map: true), gstep("vermilion-city", 3) ]),
        oak_queue: [ oak("vermilion-city", "007", 1) ])
    end

    def self.ss_anne
      loc("ss-anne", "BUILDING", "S.S. Anne", 17, steps: 3, shots: [ 3 ],
        key_items: { 3 => [ [ "HM01 Cut", "hm01_cut" ] ] },
        trainers: [ rival(1300, mon("021", 19), mon("019", 16), mon("027", 18), mon("133", 20),
          where: scene_shot("ss-anne-rival", "WHERE"),
          battle: scene_shot("battle-rival-ss-anne", "BATTLE"), opp: [ "RIVAL1", 1 ]) ])
    end

    def self.route_11
      loc("route-11", "ROUTE", "Route 11", 18, steps: [
          {},
          {},
          { hidden: [ "Escape Rope", "escape-rope", "route-11-hidden-escape-rope", "route-11-escape-rope" ] },
          { items: [ [ "Itemfinder", "itemfinder" ] ] },
          {}
        ],
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
      loc("pokemon-tower", "DUNGEON", "Pokémon Tower", 28, steps: [
          {},
          {},
          { item: [ "Escape Rope", "escape-rope" ], scene: "pokemon-tower-item-escape-rope" },
          { item: [ "Elixir", "elixir" ], scene: "pokemon-tower-item-elixir" },
          { item: [ "HP Up", "hp-up" ], scene: "pokemon-tower-item-hp-up" },
          { item: [ "Awakening", "awakening" ], scene: "pokemon-tower-item-awakening" },
          { hidden: [ "Elixir", "elixir", "pokemon-tower-hidden-elixir", "pokemon-tower-elixir" ] },
          { item: [ "Nugget", "nugget" ], scene: "pokemon-tower-item-nugget" },
          { item: [ "Rare Candy", "rare-candy" ], scene: "pokemon-tower-item-rare-candy" },
          { item: [ "X Accuracy", "x-accuracy" ], scene: "pokemon-tower-item-x-accuracy" },
          {},
          { items: [ [ "Poké Flute", "poke_flute" ] ] }
        ],
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
      loc("route-12", "ROUTE", "Route 12", 29, steps: [
          {},
          {},
          { hidden: [ "Hyper Potion", "hyper-potion", "route-12-hidden-hyper-potion", "route-12-hyper-potion" ] },
          { items: [ [ "Super Rod", "super_rod" ] ] },
          { item: [ "Iron", "iron" ], scene: "route-12-item-iron" },
          {}
        ],
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
      loc("route-13", "ROUTE", "Route 13", 30, steps: [
          {},
          { hidden: [ "Calcium", "calcium", "route-13-hidden-calcium", "route-13-calcium" ] },
          { hidden: [ "PP Up", "pp-up", "route-13-hidden-pp-up", "route-13-pp-up" ] },
          {}
        ],
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
      loc("route-15", "ROUTE", "Route 15", 32, steps: [
          { items: [ [ "Exp. All", "exp_all" ] ] },
          { item: [ "TM Rage", "tm-rage" ], scene: "route-15-item-tm-rage" },
          {}
        ],
        encounters: [
          enc("route-15", "043", "GRASS", "30%", "22–28", "COMMON", "043", "044", "045"),
          enc("route-15", "069", "GRASS", "30%", "22–28", "COMMON", "069", "070", "071"),
          enc("route-15", "048", "GRASS", "9%", "24–28", "RARE", "048", "049")
        ])
    end

    def self.fuchsia_city
      loc("fuchsia-city", "CITY", "Fuchsia City", 33, steps: 4, gym_after: 3, gym_finale: true, badge: "SOUL",
        key_items: { 2 => [ [ "Good Rod", "good_rod" ] ], 4 => [ [ "HM04 Strength", "hm04_strength" ] ] },
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
      loc("safari-zone", "DUNGEON", "Safari Zone", 34, steps: [
          {},
          {},
          { item: [ "Nugget", "nugget" ], scene: "safari-zone-item-nugget" },
          { item: [ "TM Egg Bomb", "tm-egg-bomb" ], scene: "safari-zone-item-tm-egg-bomb" },
          { item: [ "Carbos", "carbos" ], scene: "safari-zone-item-carbos" },
          { item: [ "Full Restore", "full-restore" ], scene: "safari-zone-item-full-restore" },
          { item: [ "Max Potion", "max-potion-3-7" ], scene: "safari-zone-item-max-potion-3-7", at: [ 3, 7 ] },
          { item: [ "Protein", "protein" ], scene: "safari-zone-item-protein" },
          { item: [ "TM Skull Bash", "tm-skull-bash" ], scene: "safari-zone-item-tm-skull-bash" },
          { item: [ "Gold Teeth", "gold-teeth" ], scene: "safari-zone-item-gold-teeth" },
          { item: [ "TM Double Team", "tm-double-team" ], scene: "safari-zone-item-tm-double-team" },
          { hidden: [ "Revive", "revive", "safari-zone-hidden-revive", "safari-zone-revive" ] },
          { items: [ [ "HM03 Surf", "hm03_surf" ] ] },
          { item: [ "Max Potion", "max-potion-8-20" ], scene: "safari-zone-item-max-potion-8-20", at: [ 8, 20 ] },
          { item: [ "Max Revive", "max-revive" ], scene: "safari-zone-item-max-revive" },
          {}
        ],
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
        key_items: { 1 => [ [ "HM02 Fly", "hm02_fly" ] ] },
        encounters: [
          enc("route-16", "084", "GRASS", "40%", "22–26", "COMMON", "084", "085"),
          enc("route-16", "019", "GRASS", "30%", "23–24", "COMMON", "019", "020"),
          enc("route-16", "021", "GRASS", "25%", "22–23", "UNCOMMON", "021", "022"),
          enc("route-16", "143", "STATIC", "-", "30", "STATIC", "143", tip: true)
        ],
        oak_queue: [ oak("route-16", "084", 1), oak("route-16", "143", 1) ])
    end

    def self.route_17
      loc("route-17", "ROUTE", "Route 17", 36, steps: [
          {},
          { hidden: [ "Rare Candy", "rare-candy", "route-17-hidden-rare-candy", "route-17-rare-candy" ] },
          { hidden: [ "Full Restore", "full-restore", "route-17-hidden-full-restore", "route-17-full-restore" ] },
          { hidden: [ "PP Up", "pp-up", "route-17-hidden-pp-up", "route-17-pp-up" ] },
          { hidden: [ "Max Revive", "max-revive", "route-17-hidden-max-revive", "route-17-max-revive" ] },
          { hidden: [ "Max Elixir", "max-elixir", "route-17-hidden-max-elixir", "route-17-max-elixir" ] },
          {}
        ],
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
      loc("saffron-city", "CITY", "Saffron City", 39, steps: 3, gym_after: 2, badge: "MARSH",
        trainers: [ tr("BLACK BELT", nil, 925, mon("106", 37), mon("107", 37),
          where: scene_shot("saffron-dojo-master", "WHERE")) ],
        gym: gym("saffron-city", "Saffron Gym", "PSYCHIC", "MARSH", "TM46 · PSYWAVE",
          leader("Sabrina", 4950, mon("063", 50), mon("064", 50), mon("065", 50), battle: scene_shot("battle-sabrina", "BATTLE"), opp: [ "SABRINA", 1 ]),
          puzzle: [ gstep("saffron-city", 1), gstep("saffron-city", 2, map: true), gstep("saffron-city", 3) ]),
        oak_queue: [ oak("saffron-city", "106", 1) ])
    end

    def self.silph_co
      loc("silph-co", "BUILDING", "Silph Co.", 38, steps: [
          {},
          { item: [ "Hyper Potion", "hyper-potion" ], scene: "silph-co-item-hyper-potion" },
          { item: [ "Max Revive", "max-revive" ], scene: "silph-co-item-max-revive" },
          { item: [ "Escape Rope", "escape-rope" ], scene: "silph-co-item-escape-rope" },
          { item: [ "Full Heal", "full-heal" ], scene: "silph-co-item-full-heal" },
          { item: [ "Card Key", "card-key" ], scene: "silph-co-item-card-key" },
          { item: [ "Protein", "protein" ], scene: "silph-co-item-protein" },
          { item: [ "TM Take Down", "tm-take-down" ], scene: "silph-co-item-tm-take-down" },
          { hidden: [ "Elixir", "elixir", "silph-co-hidden-elixir", "silph-co-elixir" ] },
          { item: [ "HP Up", "hp-up" ], scene: "silph-co-item-hp-up" },
          { item: [ "X Accuracy", "x-accuracy" ], scene: "silph-co-item-x-accuracy" },
          {},
          { item: [ "Calcium", "calcium" ], scene: "silph-co-item-calcium" },
          { item: [ "TM Swords Dance", "tm-swords-dance" ], scene: "silph-co-item-tm-swords-dance" },
          { hidden: [ "Max Potion", "max-potion", "silph-co-hidden-max-potion", "silph-co-max-potion" ] },
          { item: [ "TM Earthquake", "tm-earthquake" ], scene: "silph-co-item-tm-earthquake" },
          { item: [ "Rare Candy", "rare-candy" ], scene: "silph-co-item-rare-candy" },
          { item: [ "Carbos", "carbos" ], scene: "silph-co-item-carbos" },
          {},
          {}
        ],
        encounters: [ enc("silph-co", "131", "GIFT", "-", "15", "GIFT", "131", tip: true, from: true) ],
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
      loc("seafoam-islands", "CAVE", "Seafoam Islands", 42, steps: [
          {},
          {},
          { hidden: [ "Nugget", "nugget", "seafoam-islands-hidden-nugget", "seafoam-islands-nugget" ] },
          { hidden: [ "Max Elixir", "max-elixir", "seafoam-islands-hidden-max-elixir", "seafoam-islands-max-elixir" ] },
          {},
          { hidden: [ "Ultra Ball", "ultra-ball", "seafoam-islands-hidden-ultra-ball", "seafoam-islands-ultra-ball" ] },
          {}
        ],
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
      loc("pokemon-mansion", "BUILDING", "Pokémon Mansion", 45, steps: [
          {},
          { item: [ "Carbos", "carbos" ], scene: "pokemon-mansion-item-carbos" },
          { hidden: [ "Moon Stone", "moon-stone", "pokemon-mansion-hidden-moon-stone", "pokemon-mansion-moon-stone" ] },
          { item: [ "Escape Rope", "escape-rope" ], scene: "pokemon-mansion-item-escape-rope" },
          {},
          { item: [ "Calcium", "calcium" ], scene: "pokemon-mansion-item-calcium" },
          { item: [ "Iron", "iron" ], scene: "pokemon-mansion-item-iron" },
          { item: [ "Max Potion", "max-potion" ], scene: "pokemon-mansion-item-max-potion" },
          { hidden: [ "Max Revive", "max-revive", "pokemon-mansion-hidden-max-revive", "pokemon-mansion-max-revive" ] },
          {},
          { item: [ "TM Blizzard", "tm-blizzard" ], scene: "pokemon-mansion-item-tm-blizzard" },
          { item: [ "Full Restore", "full-restore" ], scene: "pokemon-mansion-item-full-restore" },
          { item: [ "Secret Key", "secret-key" ], scene: "pokemon-mansion-item-secret-key" },
          { hidden: [ "Rare Candy", "rare-candy", "pokemon-mansion-hidden-rare-candy", "pokemon-mansion-rare-candy" ] },
          { item: [ "TM Solarbeam", "tm-solarbeam" ], scene: "pokemon-mansion-item-tm-solarbeam" },
          { item: [ "Rare Candy", "rare-candy" ], scene: "pokemon-mansion-item-rare-candy" },
          {}
        ],
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
      loc("viridian-gym", "GYM", "Viridian Gym", 47, steps: [
          {},
          { item: [ "Revive", "revive" ], scene: "viridian-gym-item-revive" },
          {},
          {}
        ], gym_after: 1, badge: "EARTH",
        gym: gym("viridian-gym", "Viridian Gym", "GROUND", "EARTH", "TM27 · FISSURE",
          leader("Giovanni", 5445, mon("051", 50), mon("053", 53), mon("031", 53), mon("034", 55), mon("112", 55), battle: scene_shot("battle-giovanni-viridian", "BATTLE"), opp: [ "GIOVANNI", 3 ]),
          puzzle: [ gstep("viridian-gym", 1), gstep("viridian-gym", 2), gstep("viridian-gym", 3, map: true) ]))
    end

    def self.victory_road
      loc("victory-road", "CAVE", "Victory Road", 48, steps: [
          {},
          { item: [ "Rare Candy", "rare-candy" ], scene: "victory-road-item-rare-candy" },
          { item: [ "TM Sky Attack", "tm-sky-attack" ], scene: "victory-road-item-tm-sky-attack" },
          {},
          { hidden: [ "Ultra Ball", "ultra-ball", "victory-road-hidden-ultra-ball", "victory-road-ultra-ball" ] },
          { item: [ "Guard Spec", "guard-spec" ], scene: "victory-road-item-guard-spec" },
          {},
          { item: [ "TM Mega Kick", "tm-mega-kick" ], scene: "victory-road-item-tm-mega-kick" },
          { item: [ "Full Heal", "full-heal" ], scene: "victory-road-item-full-heal" },
          { hidden: [ "Full Restore", "full-restore", "victory-road-hidden-full-restore", "victory-road-full-restore" ] },
          { item: [ "TM Submission", "tm-submission" ], scene: "victory-road-item-tm-submission" },
          {},
          { item: [ "Max Revive", "max-revive" ], scene: "victory-road-item-max-revive" },
          { item: [ "TM Explosion", "tm-explosion" ], scene: "victory-road-item-tm-explosion" },
          {}
        ],
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
      loc("route-23", "ROUTE", "Route 23", 49, steps: [
          {},
          { hidden: [ "Max Ether", "max-ether", "route-23-hidden-max-ether", "route-23-max-ether" ] },
          { hidden: [ "Ultra Ball", "ultra-ball", "route-23-hidden-ultra-ball", "route-23-ultra-ball" ] },
          { hidden: [ "Full Restore", "full-restore", "route-23-hidden-full-restore", "route-23-full-restore" ] },
          {}
        ],
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
      loc("cerulean-cave", "CAVE", "Cerulean Cave", 51, steps: [
          {},
          { item: [ "Rare Candy", "rare-candy-29-16" ], scene: "cerulean-cave-item-rare-candy-29-16", at: [ 29, 16 ] },
          { item: [ "Max Revive", "max-revive-29-9" ], scene: "cerulean-cave-item-max-revive-29-9", at: [ 29, 9 ] },
          { hidden: [ "PP Up", "pp-up-18-7", "cerulean-cave-hidden-pp-up-18-7", "cerulean-cave-pp-up-18-7" ], at: [ 18, 7 ] },
          { item: [ "Ultra Ball", "ultra-ball-18-3" ], scene: "cerulean-cave-item-ultra-ball-18-3", at: [ 18, 3 ] },
          { item: [ "Max Elixir", "max-elixir-7-11" ], scene: "cerulean-cave-item-max-elixir-7-11", at: [ 7, 11 ] },
          {},
          { item: [ "Rare Candy", "rare-candy-0-11" ], scene: "cerulean-cave-item-rare-candy-0-11", at: [ 0, 11 ] },
          { item: [ "Ultra Ball", "ultra-ball-16-7" ], scene: "cerulean-cave-item-ultra-ball-16-7", at: [ 16, 7 ] },
          { hidden: [ "PP Up", "pp-up-16-13", "cerulean-cave-hidden-pp-up-16-13", "cerulean-cave-pp-up-16-13" ], at: [ 16, 13 ] },
          { item: [ "Max Revive", "max-revive-19-11" ], scene: "cerulean-cave-item-max-revive-19-11", at: [ 19, 11 ] },
          { item: [ "Full Restore", "full-restore" ], scene: "cerulean-cave-item-full-restore" },
          {},
          { item: [ "Ultra Ball", "ultra-ball-2-13" ], scene: "cerulean-cave-item-ultra-ball-2-13", at: [ 2, 13 ] },
          { item: [ "Max Revive", "max-revive-3-13" ], scene: "cerulean-cave-item-max-revive-3-13", at: [ 3, 13 ] },
          { hidden: [ "PP Up", "pp-up-8-14", "cerulean-cave-hidden-pp-up-8-14", "cerulean-cave-pp-up-8-14" ], at: [ 8, 14 ] },
          { item: [ "Max Elixir", "max-elixir-15-3" ], scene: "cerulean-cave-item-max-elixir-15-3", at: [ 15, 3 ] },
          { item: [ "Ultra Ball", "ultra-ball-26-1" ], scene: "cerulean-cave-item-ultra-ball-26-1", at: [ 26, 1 ] },
          {},
          {}
        ],
        encounters: [
          enc("cerulean-cave", "042", "CAVE", "40%", "50–55", "COMMON", "041", "042"),
          enc("cerulean-cave", "112", "CAVE", "15%", "58–62", "UNCOMMON", "111", "112"),
          enc("cerulean-cave", "113", "CAVE", "10%", "55–60", "UNCOMMON", "113"),
          enc("cerulean-cave", "132", "CAVE", "15%", "55–65", "UNCOMMON", "132"),
          enc("cerulean-cave", "108", "CAVE", "20%", "50–55", "UNCOMMON", "108", tip: true),
          enc("cerulean-cave", "150", "STATIC", "-", "70", "STATIC", "150", tip: true)
        ],
        oak_queue: [ oak("cerulean-cave", "150", 1), oak("cerulean-cave", "113", 1) ])
    end

    def self.route_9
      loc("route-9", "ROUTE", "Route 9", 20, steps: [
          {},
          { item: [ "TM Teleport", "tm-teleport" ], scene: "route-9-item-tm-teleport" },
          { hidden: [ "Ether", "ether", "route-9-hidden-ether", "route-9-ether" ] },
          {}
        ],
        encounters: [
          enc("route-9", "032", "GRASS", "30%", "16–18", "COMMON", "032", "033", "034"),
          enc("route-9", "029", "GRASS", "30%", "16–18", "COMMON", "029", "030", "031"),
          enc("route-9", "019", "GRASS", "15%", "18", "UNCOMMON", "019", "020"),
          enc("route-9", "021", "GRASS", "10%", "17", "UNCOMMON", "021", "022")
        ])
    end

    def self.route_10
      loc("route-10", "ROUTE", "Route 10", 21, steps: [
          {},
          {},
          { hidden: [ "Super Potion", "super-potion", "route-10-hidden-super-potion", "route-10-super-potion" ] },
          {},
          { hidden: [ "Max Ether", "max-ether", "route-10-hidden-max-ether", "route-10-max-ether" ] },
          {}
        ],
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
      loc("celadon-city", "CITY", "Celadon City", 26, steps: [
          {},
          { hidden: [ "PP Up", "pp-up", "celadon-city-hidden-pp-up", "celadon-city-pp-up" ] },
          {},
          { items: [ [ "Coin Case", "coin_case" ] ] },
          {}
        ], gym_after: 2, badge: "RAINBOW",
        encounters: [
          enc("celadon-city", "133", "GIFT", "-", "25", "GIFT", "133", tip: true, from: true),
          enc("celadon-city", "137", "GAME CORNER", "9999", "26", "GIFT", "137", tip: true),
          enc("celadon-city", "037", "GAME CORNER", "1000", "18", "GIFT", "037", "038", tip: true)
        ],
        trainers: [],
        gym: gym("celadon-city", "Celadon Gym", "GRASS", "RAINBOW", "TM21 · MEGA DRAIN",
          leader("Erika", 3168, mon("114", 30), mon("070", 32), mon("044", 32), battle: scene_shot("battle-erika", "BATTLE"), opp: [ "ERIKA", 1 ])),
        oak_queue: [ oak("celadon-city", "133", 1), oak("celadon-city", "137", 1) ])
    end

    def self.rocket_hideout
      loc("rocket-hideout", "DUNGEON", "Rocket Hideout", 27, steps: [
          {},
          {},
          { item: [ "Escape Rope", "escape-rope" ], scene: "rocket-hideout-item-escape-rope" },
          { item: [ "Hyper Potion", "hyper-potion" ], scene: "rocket-hideout-item-hyper-potion" },
          { hidden: [ "PP Up", "pp-up", "rocket-hideout-hidden-pp-up", "rocket-hideout-pp-up" ] },
          {},
          { item: [ "Nugget", "nugget" ], scene: "rocket-hideout-item-nugget" },
          { item: [ "TM Horn Drill", "tm-horn-drill" ], scene: "rocket-hideout-item-tm-horn-drill" },
          { item: [ "Moon Stone", "moon-stone" ], scene: "rocket-hideout-item-moon-stone" },
          { item: [ "Super Potion", "super-potion" ], scene: "rocket-hideout-item-super-potion" },
          {},
          { item: [ "Rare Candy", "rare-candy" ], scene: "rocket-hideout-item-rare-candy" },
          { item: [ "TM Double Edge", "tm-double-edge" ], scene: "rocket-hideout-item-tm-double-edge" },
          { hidden: [ "Nugget", "nugget", "rocket-hideout-hidden-nugget", "rocket-hideout-nugget" ] },
          {},
          { item: [ "Lift Key", "lift-key" ], scene: "rocket-hideout-item-lift-key" },
          { item: [ "TM Razor Wind", "tm-razor-wind" ], scene: "rocket-hideout-item-tm-razor-wind" },
          { item: [ "HP Up", "hp-up" ], scene: "rocket-hideout-item-hp-up" },
          { item: [ "Iron", "iron" ], scene: "rocket-hideout-item-iron" },
          {},
          {},
          { item: [ "Silph Scope", "silph-scope" ], scene: "rocket-hideout-item-silph-scope" },
          { hidden: [ "Super Potion", "super-potion", "rocket-hideout-hidden-super-potion", "rocket-hideout-super-potion" ] },
          {}
        ],
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
      loc("power-plant", "BUILDING", "Power Plant", 43, steps: [
          {},
          { item: [ "Carbos", "carbos" ], scene: "power-plant-item-carbos" },
          {},
          {},
          {},
          { item: [ "TM Reflect", "tm-reflect" ], scene: "power-plant-item-tm-reflect" },
          {},
          { item: [ "TM Thunder", "tm-thunder" ], scene: "power-plant-item-tm-thunder" },
          {},
          { hidden: [ "Max Elixir", "max-elixir", "power-plant-hidden-max-elixir", "power-plant-max-elixir" ] },
          {},
          {},
          { item: [ "HP Up", "hp-up" ], scene: "power-plant-item-hp-up" },
          { item: [ "Rare Candy", "rare-candy" ], scene: "power-plant-item-rare-candy" },
          {},
          { hidden: [ "PP Up", "pp-up", "power-plant-hidden-pp-up", "power-plant-pp-up" ] },
          {},
          {}
        ],
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

    # The game spells a few items differently from their PokeAPI sprite file, so pin those here;
    # every other name kebab-cases straight onto its sprite.
    ITEM_SPRITES = {
      "TM34 Bide" => "tm-normal", "Oak's Parcel" => "oaks-parcel", "TM42 Dream Eater" => "tm-psychic",
      "HM05 Flash" => "tm-normal", "HM01 Cut" => "tm-normal", "HM02 Fly" => "tm-flying",
      "HM03 Surf" => "tm-water", "HM04 Strength" => "tm-normal",
      "Parlyz Heal" => "paralyze-heal", "X Defend" => "x-defense", "Fossil" => "dome-fossil"
    }.freeze

    def self.item_sprite(name)
      ITEM_SPRITES.fetch(name) { tm_sprite(name) || name.downcase.gsub("é", "e").gsub(/[^a-z0-9]+/, "-") }
    end

    # A ground TM ball wears its move's type badge (tm-<type>), the same sprite the Mart uses, rather
    # than a per-move icon that does not exist.
    def self.tm_sprite(name)
      name.start_with?("TM") ? "tm-#{item_catalog.fetch(name)['type']}" : nil
    end

    # Cities (and Lavender Town) with a Poké Mart, mapped to the map const whose generated stock
    # the section lists. Celadon is the Dept. Store, built floor by floor below.
    MART_CONSTS = {
      "viridian-city" => "VIRIDIAN_MART", "pewter-city" => "PEWTER_MART",
      "cerulean-city" => "CERULEAN_MART", "vermilion-city" => "VERMILION_MART",
      "lavender-town" => "LAVENDER_MART", "fuchsia-city" => "FUCHSIA_MART",
      "saffron-city" => "SAFFRON_MART", "cinnabar-island" => "CINNABAR_MART"
    }.freeze

    # The items each mart flags as worth stocking up on (the ★ rows), by display name.
    MART_RECS = {
      "viridian-city" => [ "Poké Ball", "Antidote" ], "pewter-city" => [ "Poké Ball", "Escape Rope" ],
      "cerulean-city" => [ "Poké Ball", "Repel" ], "vermilion-city" => [ "Super Potion", "Repel" ],
      "lavender-town" => [ "Great Ball", "Super Repel" ], "fuchsia-city" => [ "Ultra Ball", "Hyper Potion" ],
      "saffron-city" => [ "Hyper Potion", "Max Repel" ], "cinnabar-island" => [ "Ultra Ball", "Full Heal" ]
    }.freeze

    # The Celadon floors whose stock the game states; the rest (services, the rooftop drinks) are
    # arranged by hand in celadon_dept_store.
    CELADON_FLOOR_CONSTS = {
      "2F" => "CELADON_MART_2F", "4F" => "CELADON_MART_4F", "5F" => "CELADON_MART_5F"
    }.freeze

    VITAMINS = [ "HP Up", "Protein", "Iron", "Carbos", "Calcium" ].freeze

    def self.item_key(name)
      facts = item_catalog.fetch(name)
      return facts["move"].downcase.gsub(/[^a-z0-9]+/, "_") if facts["tm"]

      item_sprite(name).tr("-", "_")
    end

    def self.mart_item(name, rec: false, rec_key: nil, desc_key: nil)
      facts = item_catalog.fetch(name)
      tm = facts["tm"]
      MartItem.new(name: name, sprite: (tm ? "tm-#{facts['type']}" : item_sprite(name)),
        price: facts["price"], desc_key: mart_desc_key(name, tm, desc_key),
        tm_no: tm, move: facts["move"], mtype: facts["type"],
        rec: (rec || !rec_key.nil?), rec_key: rec_key)
    end

    # A TM's own description would be a lie (Gen 1 gives them none), so a sold TM shows the type of
    # move it teaches instead; the free TM18 gift passes its own written blurb.
    def self.mart_desc_key(name, tm, given)
      return given if given
      return nil if tm

      "walkthrough.ui.mart_items.#{item_key(name)}"
    end

    def self.mart(slug)
      b = base(slug)
      recs = MART_RECS.fetch(slug, [])
      items = place_facts.fetch(MART_CONSTS.fetch(slug)).stock.map do |name|
        mart_item(name, rec: recs.include?(name))
      end
      Mart.new(slug: slug, count: items.size, blurb_key: "#{b}.mart.blurb",
        buy_key: "#{b}.mart.buy", counters: [ MartCounter.new(items: items) ])
    end

    def self.attach_mart(loc)
      return loc.with(mart: celadon_dept_store) if loc.slug == "celadon-city"
      return loc.with(mart: mart(loc.slug)) if MART_CONSTS.key?(loc.slug)

      loc
    end

    def self.celadon_stock(id) = place_facts.fetch(CELADON_FLOOR_CONSTS.fetch(id)).stock

    def self.celadon_dept_store
      shop, tms = celadon_stock("2F").partition { |name| item_catalog.fetch(name)["tm"].nil? }
      vitamins, battle = celadon_stock("5F").partition { |name| VITAMINS.include?(name) }
      b = base("celadon-city")
      floors = [
        dept_floor("1F", "service", note: true),
        dept_floor("2F", "shop", counters: [
          dept_counter("2F", "mart_item_counter", shop, rec: [ "Great Ball", "Super Potion" ]),
          dept_counter("2F", "mart_tm_counter", tms, rec: [ "TM Take Down" ])
        ]),
        dept_floor("3F", "free_tm", note: true,
          gift: mart_item("TM18 Counter", desc_key: "#{b}.store.floors.3F.gift_desc")),
        dept_floor("4F", "shop", counters: [
          dept_counter("4F", "mart_gift_counter", celadon_stock("4F"), rec: [ "Water Stone" ])
        ]),
        dept_floor("5F", "shop", counters: [
          dept_counter("5F", "mart_vitamins", vitamins),
          dept_counter("5F", "mart_battle_items", battle)
        ]),
        dept_floor("ROOF", "vending", note: true,
          counters: [ dept_counter("ROOF", "mart_vending",
            [ "Fresh Water", "Soda Pop", "Lemonade" ], rec: [ "Fresh Water", "Soda Pop", "Lemonade" ]) ],
          trades: celadon_trades)
      ]
      Mart.new(slug: "celadon-city", blurb_key: "#{b}.store.blurb", floors: floors,
        count: floors.sum { |floor| floor.counters.sum { |counter| counter.items.size } })
    end

    def self.dept_floor(id, kind, counters: [], gift: nil, trades: [], note: false)
      b = base("celadon-city")
      MartFloor.new(id: id, label: id, kind: kind,
        name_key: "#{b}.store.floors.#{id}.name", motto_key: "#{b}.store.floors.#{id}.motto",
        note_key: (note ? "#{b}.store.floors.#{id}.note" : nil),
        gift: gift, counters: counters, trades: trades)
    end

    def self.dept_counter(floor_id, title, names, rec: [])
      b = base("celadon-city")
      MartCounter.new(title_key: "walkthrough.ui.#{title}", items: names.map do |name|
        mart_item(name, rec_key: (rec.include?(name) ? "#{b}.store.floors.#{floor_id}.rec.#{item_key(name)}" : nil))
      end)
    end

    def self.celadon_trades
      [ [ "Fresh Water", "TM13 Ice Beam" ], [ "Soda Pop", "TM48 Rock Slide" ],
        [ "Lemonade", "TM49 Tri Attack" ] ].map do |drink, tm|
        facts = item_catalog.fetch(tm)
        MartTrade.new(drink: drink, drink_sprite: item_sprite(drink),
          tm_short: "TM#{format('%02d', facts['tm'])}", tm_sprite: "tm-#{facts['type']}",
          move: facts["move"])
      end
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

    def self.trivia(base, anchor:, cards: [], shot: nil, yellow_only: true)
      Trivia.new(anchor: anchor, title_key: "#{base}.trivia.title", intro_key: "#{base}.trivia.intro",
        note_key: "#{base}.trivia.note", cards: cards, shot: shot, yellow_only: yellow_only)
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
