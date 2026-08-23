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
    def self.enc(slug, dex, how, rate, level, rarity, *chain, tip: false, from: false, unlock: nil,
      badge: nil)
      b = base(slug)
      key = mon_key(dex)
      places = encounter_places(slug, dex)
      head = headline(places, how) || [ rate, level ]
      Encounter.new(dex: dex, name: NAMES.fetch(dex), how: how, rate: head.first, level: head.last,
        rarity: rarity, tip_key: (tip ? "#{b}.tips.#{key}" : nil), evo_line: line(*chain),
        from_key: (from ? "#{b}.gifts.#{key}.from" : nil),
        unlock_key: (unlock ? "#{b}.gifts.#{key}.unlock" : nil), unlock_icon: unlock,
        needs_badge: badge, places: places, at_map: slug)
    end

    # A species spread over several floors has no single hand-typed rate that is true; the card
    # would otherwise headline one floor's number above a breakdown that contradicts it. So the
    # headline is the best floor you can reach, rounded to the whole percent `parse_rate` reads,
    # over the level band across every floor it lives on.
    #
    # Only the places matching the card's own method count. Which method a stop expects you to
    # use is an editorial call (the guide sends you Surfing at Seafoam, not fishing off the same
    # tile), so the tag stays put and the number is made true for it; the breakdown below the
    # headline still lists every other way the species turns up there. Returns nil when the
    # method has no table at all (gifts, fossils, the Game Corner), leaving the hand-typed pair.
    def self.headline(places, how)
      matching = places.select { |place| place.method?(how) }
      return nil if matching.size < 2

      lo = matching.map(&:min_level).min
      hi = matching.map(&:max_level).max
      [ "#{matching.map(&:rate).max.round}%", lo == hi ? lo.to_s : "#{lo}–#{hi}" ]
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

    # The eight badges in case order, with what each one switches on: `boost` names the stat every
    # Pokémon you send out gains about 12.5% of, `obey` the level a traded Pokémon obeys up to, and
    # `field` the HM the badge licenses outside battle. Leaders and cities repeat what the gym
    # definitions below already say; a model test holds the two in step.
    BADGES = [
      { name: "Boulder", leader: "Brock",     city: "Pewter City",     boost: "attack",  field: "Flash" },
      { name: "Cascade", leader: "Misty",     city: "Cerulean City",   obey: 30,         field: "Cut" },
      { name: "Thunder", leader: "Lt. Surge", city: "Vermilion City",  boost: "defense", field: "Fly" },
      { name: "Rainbow", leader: "Erika",     city: "Celadon City",    obey: 50,         field: "Strength" },
      { name: "Soul",    leader: "Koga",      city: "Fuchsia City",    boost: "speed",   field: "Surf" },
      { name: "Marsh",   leader: "Sabrina",   city: "Saffron City",    obey: 70 },
      { name: "Volcano", leader: "Blaine",    city: "Cinnabar Island", boost: "special" },
      { name: "Earth",   leader: "Giovanni",  city: "Viridian City",   obey: 100 }
    ].freeze

    BADGE_RULES = %w[boost stacking caps field_moves].freeze

    def self.badge_img(badge) = "walkthrough/yellow/badges/#{badge.downcase}.png"

    def self.badge_guide
      b = "#{K}.badge_guide"
      BadgeGuide.new(anchor: "badges-explained",
        cards: BADGES.each_with_index.map { |badge, i| badge_card(b, badge, i + 1) },
        rules: BADGE_RULES.each_with_index.map { |key, i|
          BadgeRule.new(no: i + 1, label_key: "#{b}.rules.#{key}.label",
            title_key: "#{b}.rules.#{key}.title", text_key: "#{b}.rules.#{key}.text")
        })
    end

    def self.badge_card(base, badge, no)
      obey = badge[:obey]
      BadgeCard.new(no: no, name: badge[:name], image: badge_img(badge[:name]),
        leader: badge[:leader], city: badge[:city], kind: obey ? "obey" : "boost",
        effect_key: obey ? "#{base}.obey" : "#{base}.boost.#{badge[:boost]}",
        level: obey, field: badge[:field])
    end

    def self.oak(slug, dex, qty)
      OakEntry.new(dex: dex, name: NAMES.fetch(dex), qty: qty, why_key: "#{base(slug)}.oak.#{mon_key(dex)}")
    end

    def self.trade(slug, key, give, receive, nick, house:, inside:, tick: nil)
      b = base(slug)
      Trade.new(
        give: { dex: give, name: NAMES.fetch(give) },
        receive: { dex: receive, name: NAMES.fetch(receive) },
        nick: nick, npc_key: "#{b}.trades.#{key}.npc", title_key: "#{b}.trades.#{key}.title",
        where_key: "#{b}.trades.#{key}.where", note_key: "#{b}.trades.#{key}.note",
        house: scene_shot(house, WHERE_LABEL), inside: scene_shot(inside, INSIDE_LABEL), tick: tick,
        at_map: slug
      )
    end

    LEG_DEFS = [
      { slug: "leg-01", special: false, locs: %w[pallet-town route-1] },
      { slug: "leg-02", special: false, locs: %w[viridian-city route-22 route-2] },
      { slug: "viridian-forest", special: true, locs: %w[viridian-forest] },
      { slug: "leg-03", special: false, locs: %w[pewter-city route-3 route-4-mt-moon] },
      { slug: "mt-moon", special: true, locs: %w[mt-moon] },
      { slug: "leg-04", special: false, locs: %w[route-4 cerulean-city route-24 route-25] },
      { slug: "leg-05", special: false, locs: %w[route-5 underground-path route-6 vermilion-city] },
      { slug: "ss-anne", special: true, locs: %w[ss-anne] },
      { slug: "leg-06", special: false, locs: %w[route-11 vermilion-city-return] },
      { slug: "digletts-cave", special: true, locs: %w[digletts-cave] },
      { slug: "leg-07", special: false, locs: %w[route-9 route-10] },
      { slug: "rock-tunnel", special: true, locs: %w[rock-tunnel] },
      { slug: "leg-08", special: false, locs: %w[route-10-south lavender-town route-8 underground-path-west-east route-7] },
      { slug: "leg-09", special: false, locs: %w[celadon-city] },
      { slug: "rocket-hideout", special: true, locs: %w[rocket-hideout] },
      { slug: "leg-10", special: false, locs: %w[celadon-city-return] },
      { slug: "pokemon-tower", special: true, locs: %w[pokemon-tower] },
      { slug: "leg-11", special: false, locs: %w[route-12 route-13 route-14 route-15 fuchsia-city safari-zone] },
      { slug: "silph-co", special: true, locs: %w[silph-co] },
      { slug: "leg-12", special: false, locs: %w[route-16 route-17 route-18 saffron-city] },
      { slug: "leg-13", special: false, locs: %w[route-19 route-20] },
      { slug: "seafoam-islands", special: true, locs: %w[seafoam-islands] },
      { slug: "power-plant", special: true, locs: %w[power-plant] },
      { slug: "leg-14", special: false, locs: %w[cinnabar-island pokemon-mansion route-21] },
      { slug: "leg-15", special: false, locs: %w[viridian-gym] },
      { slug: "victory-road", special: true, locs: %w[victory-road] },
      { slug: "leg-16", special: false, locs: %w[route-23] },
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
        found = best_catch(dex, entries)
        best[dex] = found if found
      end
    end

    def self.best_catch(dex, entries)
      armed = entries.select { |entry| entry[:enc].unlocked_from <= entry[:loc].order }
      return nil if armed.empty?
      return sole_catch(dex, armed.first, entries.one?) if armed.one?

      ranked_catch(dex, armed)
    end

    def self.sole_catch(dex, entry, anywhere = true)
      BestCatch.new(
        dex: dex, slug: entry[:loc].slug, only: anywhere, armed_only: !anywhere,
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
        route_5, underground_path, route_6, vermilion_city, ss_anne, route_11,
        vermilion_city_return, digletts_cave,
        route_9, route_10, rock_tunnel, route_10_south, lavender_town, route_8,
        underground_path_west_east, route_7, celadon_city,
        rocket_hideout, celadon_city_return,
        pokemon_tower, route_12, route_13, route_14, route_15, fuchsia_city, safari_zone,
        route_16, route_17, route_18, silph_co, saffron_city, route_19, route_20, seafoam_islands,
        power_plant, cinnabar_island, pokemon_mansion, route_21, viridian_gym, victory_road, route_23,
        indigo_plateau, cerulean_cave
      ].map { |loc| attach_mart(attach_maps(loc, maps_for(loc.slug, data))) }
      show_mt_moon_approach(locs)
    end

    # A stop the guide walks twice has map data under one slug only. The second pass reads the
    # first pass's maps, so the same interactive map (markers, tick state) shows on both.
    MAP_SOURCE = { "vermilion-city-return" => "vermilion-city",
                   "celadon-city-return" => "celadon-city",
                   "route-10-south" => "route-10" }.freeze

    # A stop that walks off its own map borrows the maps it steps onto, keyed by the name to draw
    # over them. Diglett's Cave surfaces on Route 2, carries on into Viridian City and doubles back
    # up to Pewter, so every page has to hand the reader the same markers and the same ticks.
    MAP_EXTRA = {
      "digletts-cave" => { "route-2" => "Route 2", "viridian-city" => "Viridian City",
                           "pewter-city" => "Pewter City" }
    }.freeze

    def self.maps_for(slug, data)
      own = data.fetch(MAP_SOURCE.fetch(slug, slug), [])
      own + MAP_EXTRA.fetch(slug, {}).flat_map do |from, title|
        data.fetch(from, []).map { |map| map.with(title: title) }
      end
    end

    # The leg-3 approach section has no map data of its own; it borrows Route 4's map so the same
    # interactive map (markers, tick state) shows on both the approach (leg 3) and the east half
    # (leg 4). Its steps resolve their pin letters here, since until now it had no map to read them
    # from.
    def self.show_mt_moon_approach(locs)
      route_4_maps = locs.find { |loc| loc.slug == "route-4" }.area_maps
      locs.map do |loc|
        next loc unless loc.slug == "route-4-mt-moon"

        mark_steps(loc.with(area_maps: route_4_maps), route_4_maps)
      end
    end

    # The gym's own map belongs in the gym section, not the location header, so pull the "Gym"
    # floor out of the header maps and hand it to the gym as its shot.
    def self.attach_maps(loc, maps)
      gym_map = maps.find { |m| m.floor == "Gym" }
      header = maps.reject { |m| m.floor == "Gym" }
      loc = apply_trainer_notes(map_steps(mark_steps(tick_items(merge_trainers(loc), header), header),
        header))
      header = link_steps(loc, header)
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

    # A pin and the step that picks it up are one instruction seen twice, so the pin carries that
    # step's number home: tapping a marker on the map offers the step that explains it. Reuses the
    # tick target the cards already resolved, which is the same map-and-pin pair.
    # Turn each step's authored pin ids into the letters those pins wear right now, so the prose
    # can say "exit K" without anyone having to keep a letter written down anywhere.
    def self.mark_steps(loc, maps)
      # The Mt. Moon approach owns no map, so it resolves later, once it has borrowed Route 4's.
      return loc if maps.empty?

      letters = maps.flat_map { |m| m.markers.map { |k| [ "#{m.name}/#{k.id}", k.key ] } }.to_h
      loc.with(steps: loc.steps.map { |step| marked(step, letters) },
        trivia: loc.trivia && marked(loc.trivia, letters))
    end

    # A step and a trivia section both point at map pins the same way, so they are marked the same
    # way: whatever the prose named, swapped for the letter that pin is wearing right now.
    def self.marked(block, letters)
      return block if block.pins.empty?

      block.with(marks: block.pins.transform_values { |id| letters.fetch(id) })
    end

    # How much floor a step's own map shows around the stretch it walks, in map pixels. Tight
    # enough that a short hop fills the frame, wide enough that the reader can see which part of
    # the floor they are looking at rather than a patch of green with a line on it.
    STEP_MAP_PAD = 40
    STEP_MAP_MIN = 240

    # A step that walks a stretch of a drawn route gets its own copy of the floor, cropped to it.
    # Authored as ["map name", first leg, last leg]: the legs are the route's own, so a step and
    # the overview cannot disagree about which way round the maze goes, and a step that owns two
    # in a row (walk to the ball, then out of the room) draws them both.
    def self.map_steps(loc, maps)
      by_name = maps.to_h { |map| [ map.name, map ] }
      loc.with(steps: loc.steps.map do |step|
        next step unless step.line?

        step.with(step_map: step_map(by_name.fetch(step.line.first), *step.line.drop(1)))
      end)
    end

    def self.step_map(area, first, last = first)
      legs = area.route_legs[(first - 1)..(last - 1)]
      StepMap.new(image: area.image, width: area.width, height: area.height,
        box: crop_box(legs, floor_bounds(area)), legs: legs)
    end

    # The part of the picture worth cropping into, as [x0, y0, x1, y1]. A map's image is the whole
    # grid and a floor rarely fills it: B2F leaves six rows of black above its own top wall, and a
    # frame centred near the top would spend a quarter of itself on that. Every point of the route
    # is somewhere the player stands, so the box they span, opened out by a margin and kept inside
    # the image, is a fair read on where the floor is.
    def self.floor_bounds(area)
      xs, ys = area.route.flatten(1).transpose
      [ [ xs.min - STEP_MAP_PAD, 0 ].max, [ ys.min - STEP_MAP_PAD, 0 ].max,
        [ xs.max + STEP_MAP_PAD, area.width ].min, [ ys.max + STEP_MAP_PAD, area.height ].min ]
    end

    # The crop, as the SVG viewBox [x, y, w, h]: a window the size of the leg plus a margin,
    # centred on it and slid back inside the picture so a leg against the wall does not crop to
    # empty space beyond the map's edge.
    def self.crop_box(legs, bounds)
      left, top, right, bottom = bounds
      xs, ys = legs.flat_map(&:points).transpose
      box_w, box_h = window(xs.max - xs.min, ys.max - ys.min, right - left, bottom - top)
      [ left + slide(xs.min + xs.max - left * 2, box_w, right - left),
        top + slide(ys.min + ys.max - top * 2, box_h, bottom - top), box_w, box_h ]
    end

    # How big a window to cut. Always 4:3, whichever way the leg runs: a leg that goes straight
    # down a corridor would otherwise crop to a tall slot, and a page of frames all different
    # shapes reads as a mess next to one where each is the same window onto a different place.
    def self.window(span_x, span_y, width, height)
      wide = [ span_x + STEP_MAP_PAD * 2, STEP_MAP_MIN ].max
      tall = [ span_y + STEP_MAP_PAD * 2, STEP_MAP_MIN * 3 / 4 ].max
      box_w = [ [ wide, tall * 4 / 3 ].max, width, height * 4 / 3 ].min
      [ box_w, box_w * 3 / 4 ]
    end

    # Where one axis of that window starts: centred on the leg, then slid back inside the floor.
    # `window` never returns a span wider than the floor, so the far clamp only ever guards
    # against a zero-width one.
    def self.slide(span_ends, span, limit)
      ((span_ends - span) / 2).clamp(0, [ limit - span, 0 ].max)
    end

    def self.link_steps(loc, maps)
      steps = loc.steps.flat_map { |s| (s.items + s.hidden).map { |i| [ i.tick, s.n ] } }.to_h
      maps.map do |map|
        map.with(markers: map.markers.map do |pin|
          n = steps["#{map.name}/#{pin.id}"]
          n ? pin.with(step: n) : pin
        end)
      end
    end

    def self.tick_items(loc, maps)
      pins = maps.flat_map { |m| m.markers.map { |k| [ m.name, k ] } }
      loc.with(later: loc.later.map { |l| key_later(pins, l) },
        steps: loc.steps.map do |step|
          step.with(items: step.items.map { |i| join_pin(pins, "item", i) },
            hidden: step.hidden.map { |h| join_pin(pins, "hidden", h) })
        end)
    end

    # A card and its pin are the same thing seen twice, so the card carries the pin's tick target
    # (so ticking either flips both) and the pin's letter (so a reader can find it on the map).
    # An ambiguous match leaves both nil rather than pointing at the wrong ball.
    def self.join_pin(pins, cat, item)
      map_name, pin = find_pin(pins, cat, item.name, item.at)
      return item if pin.nil?

      item.with(tick: "#{map_name}/#{pin.id}", key: pin.key)
    end

    # A later item still sits on the map, so its card has to say which letter to look for, and it
    # ticks off against that pin: the stop that finally walks to it lists the same thing, and one
    # item collected once should read as collected on both pages.
    def self.key_later(pins, item)
      map_name, pin = later_pin(pins, item.name)
      pin ? item.with(key: pin.key, tick: "#{map_name}/#{pin.id}") : item
    end

    # A locked item is a ball on the ground or a stash you press A for, and the map draws both, so
    # look in either category. Only an NPC gift is on no map at all; that one keeps the id it was
    # built with (gift_tick), since there is no pin to take one from.
    def self.later_pin(pins, name)
      ball = find_pin(pins, "item", name, nil)
      ball.last ? ball : find_pin(pins, "hidden", name, nil)
    end

    def self.find_pin(pins, cat, name, at)
      found = pins.select { |_map, pin| pin.cat == cat && pin.name == name }
      found = found.select { |_map, pin| pin.id.end_with?("-#{at[0]}-#{at[1]}") } if at
      found.one? ? found.first : [ nil, nil ]
    end

    def self.authored_cards(loc)
      loc.trainers + (loc.gym ? loc.gym.trainers + [ loc.gym.leader ] : [])
    end

    # Curated captions stamped onto specific trainers by their OPP_CLASS:party id, keyed by
    # location. Cerulean's Swimmer and Misty carry the Mew-glitch warnings; Route 4's east-plateau
    # Lass and Route 10's Power Plant Pokémaniac carry "you cannot reach this one yet" heads-ups.
    def self.trainer_notes(slug)
      b = base(slug)
      case slug
      when "cerulean-city"
        { "SWIMMER:1" => "#{b}.gym.notes.swimmer", "MISTY:1" => "#{b}.gym.notes.misty" }
      when "route-4"
        { "LASS:4" => "#{b}.trainers.lass.note" }
      when "route-10"
        { "POKEMANIAC:1" => "#{b}.trainers.pokemaniac.note" }
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
        marker_key: card.marker_key || entry["key"], tick: card.tick || tick_for(entry),
        floor: floor_of(entry))
    end

    def self.roster_trainer(entry)
      label = class_label(entry["cls"])
      Trainer.new(cls: label, name: nil, reward: entry["reward"],
        team: entry["team"].map { |m| mon(m["dex"], m["lvl"]) },
        sprite: trainer_sprite(label, nil),
        where: Shot.new(image: entry["where"], label: WHERE_LABEL), battle: nil,
        opp: entry["opp"], marker_key: entry["key"], tick: tick_for(entry),
        floor: floor_of(entry))
    end

    # A one-floor map leaves the field empty, and every trainer inside a gym reads "Gym", neither
    # of which tells a reader anything a card does not already say.
    def self.floor_of(entry) = entry["floor"].presence

    def self.tick_for(entry) = "#{entry['map']}/#{entry['marker']}"

    # Route 10 is one map walked twice, so its six trainers have to be dealt out between the two
    # passes. Three pockets, not two: the Jr Trainer below the Poké Center is on the north half,
    # the Hikers, a Pokémaniac and the second Jr Trainer are past the tunnel, and the Pokémaniac
    # guarding the Power Plant's door stands on a middle strip walled off by water. That one is
    # listed on the north half, where the walkthrough tells you to come back for it with Surf.
    ROSTER_SPLIT = {
      "route-10" => %w[JR_TRAINER_F:7 POKEMANIAC:1],
      "route-10-south" => %w[POKEMANIAC:2 HIKER:7 HIKER:8 JR_TRAINER_F:8]
    }.freeze

    def self.roster_for(slug)
      entries = roster.fetch("trainers", {}).fetch(MAP_SOURCE.fetch(slug, slug), [])
      half = ROSTER_SPLIT[slug]
      half ? entries.select { |entry| half.include?(entry["opp"]) } : entries
    end

    def self.roster
      @roster ||= JSON.parse(File.read(File.join(__dir__, "yellow_trainers.json"))).freeze
    end

    def self.manifest
      @manifest ||= JSON.parse(File.read(File.join(__dir__, "yellow_maps.json"))).freeze
    end

    def self.wild_tables
      @wild_tables ||= JSON.parse(File.read(File.join(__dir__, "yellow_encounters.json")))
        .fetch("encounters").freeze
    end

    # Where one species really spawns inside a location, floor by floor. Gen 1 gives every map its
    # own table, so a cave's floors disagree on both who is there and how often: Sandshrew is on
    # Mt. Moon 1F alone, and Clefairy climbs from 1.2% there to 10.5% on B2F. A single headline
    # rate cannot say that, so the card lists the places and lets the player pick the best one.
    def self.encounter_places(slug, dex)
      wild_tables.fetch(slug, []).filter_map do |place|
        row = place.fetch("mons").find { |mon| mon["dex"] == dex }
        next if row.nil?

        EncounterPlace.new(floor: place["floor"].presence, kind: place.fetch("kind"),
          rate: row.fetch("rate"), min_level: row.fetch("min_level"),
          max_level: row.fetch("max_level"))
      end
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
          # NPCs are their own category, so they number from N1 like every other kind does.
          npcs = npc_overlay.fetch(m["name"], []).each_with_index.map do |n, i|
            npc_marker(n, m["width"], m["height"], key_letter(i))
          end
          AreaMap.new(image: m["image"], width: m["width"], height: m["height"], floor: m["floor"],
            name: m["name"], markers: base + npcs, route: m.fetch("route", []))
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

    def self.map_marker(data, key = data["key"])
      MapMarker.new(id: data["id"], cat: data["cat"], key: key, name: data["name"],
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

    # An NPC pin's key: the same N1, N2 ... shape the generator gives every other category.
    def self.key_letter(index) = "N#{index + 1}"

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
          step(b, 1, items: [ item(b, 1, "Potion", "potion") ], shot: map_shot("pallet-town", 1, "STEP 1"),
            pins: { home: "pallet-town/exit-5-5" }),
          step(b, 2, pins: { north: "pallet-town/exit-north", lab: "pallet-town/exit-12-11" }),
          step(b, 3, html: true, link: StepLink.new(leg: "leg-01", anchor: RIVAL_EEVEE_ANCHOR)),
          step(b, 4, shot: map_shot("pallet-town", 4, "STEP 4"), pins: { north: "pallet-town/exit-north" })
        ],
        encounters: [
          enc("pallet-town", "025", "STARTER", "-", "5", "GIFT", "025", "026", tip: true),
          enc("pallet-town", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("pallet-town", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("pallet-town", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("pallet-town", "120", "SUPER ROD", "60%", "5–10", "COMMON", "120", "121"),
          enc("pallet-town", "072", "SUPER ROD", "40%", "10–20", "COMMON", "072", "073")
        ],
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
          step(b, 2, items: [ item(b, 2, "Potion", "potion") ], pins: { man: "route-1/npc-potion-sample" }),
          step(b, 3, pins: { north: "route-1/exit-north" })
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
          { item: [ "Oak's Parcel", "oaks_parcel" ], scene: "viridian-mart-parcel",
            pins: { center: "viridian-city/exit-23-25", mart: "viridian-city/exit-29-19" } },
          { item: [ "Pokédex", "pokedex" ] },
          { item: [ "Town Map", "town_map" ], scene: "blues-house-town-map" },
          {},
          {},
          { hidden: [ "Potion", "potion", "viridian-city-hidden-potion", "viridian-city-potion" ],
            pins: { north: "viridian-city/exit-north" } },
          { pins: { gym: "viridian-city/exit-32-7", west: "viridian-city/exit-west" } }
        ]),
        encounters: [
          enc("viridian-city", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("viridian-city", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("viridian-city", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("viridian-city", "060", "SUPER ROD", "100%", "5–15", "COMMON", "060", "061", "062")
        ],
        trainers: [], oak_queue: [],
        later: [ later("viridian-city", "tm42", "TM42 Dream Eater", "ITEM", "Cut or Surf", "viridian-city-tm42") ],
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
          enc("route-22", "021", "GRASS", "10%", "2–6", "UNCOMMON", "021", "022", tip: true),
          enc("route-22", "019", "GRASS", "10%", "3", "UNCOMMON", "019", "020", tip: true),
          enc("route-22", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("route-22", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("route-22", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("route-22", "060", "SUPER ROD", "90%", "5–15", "COMMON", "060", "061", "062"),
          enc("route-22", "061", "SUPER ROD", "10%", "15", "UNCOMMON", "060", "061", "062")
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
          { scene: "viridian-forest-south-gate", pins: { gate: "route-2/exit-3-43" } }
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
          later("route-2", "moon_stone", "Moon Stone", "ITEM", "Cut", "route-2-moon-stone"),
          later("route-2", "hp_up", "HP Up", "ITEM", "Cut", "route-2-hp-up"),
          later("route-2", "flash", "HM05 Flash", "HM", "Cut · 10 caught", "route-2-flash")
        ]
      )
    end

    def self.viridian_forest
      b = base("viridian-forest")
      Location.new(
        slug: "viridian-forest", kind: "FOREST", name: "Viridian Forest", order: 6, badge: nil,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: build_steps(b, [
          { pins: { lass: "viridian-forest/trainer-2-41" } },
          { hidden: [ "Antidote", "antidote", "viridian-forest-hidden-antidote", "viridian-forest-antidote" ] },
          { item: [ "Poké Ball", "pok-ball" ], scene: "viridian-forest-item-pok-ball" },
          { item: [ "Potion", "potion-25-11" ], scene: "viridian-forest-item-potion-25-11", at: [ 25, 11 ],
            pins: { low: "viridian-forest/trainer-30-33", high: "viridian-forest/trainer-30-19" } },
          { item: [ "Potion", "potion-12-29" ], scene: "viridian-forest-item-potion-12-29", at: [ 12, 29 ],
            pins: { middle: "viridian-forest/trainer-13-17" } },
          { hidden: [ "Potion", "potion", "viridian-forest-hidden-potion", "viridian-forest-potion" ],
            pins: { west: "viridian-forest/trainer-2-18" } },
          { scene: "viridian-forest-north", pins: { north: "viridian-forest/exit-1-0" } }
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
          step(b, 1, shot: map_shot("pewter-city", 1, "STEP 1"),
            pins: { center: "pewter-city/exit-13-25", mart: "pewter-city/exit-23-17", gym: "pewter-city/exit-16-17" }),
          step(b, 2, pins: { east: "pewter-city/exit-east" })
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

    def self.loc(slug, kind, name, order, title: nil, steps: 3, shots: [], hidden_items: {}, key_items: {}, pins: {}, encounters: [], trainers: [], trades: [], oak_queue: [], badge: nil, gym: nil, gym_after: nil, gym_finale: false, trivia: nil, grind: nil)
      b = base(slug)
      Location.new(
        slug: slug, kind: kind, name: name, title: title, order: order, badge: badge,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: steps.is_a?(Array) ? build_steps(b, steps, pins) : (1..steps).map { |i|
          step(b, i, pins: pins.fetch(i, {}),
            shot: shots.include?(i) ? map_shot(slug, i, "STEP #{i}") : nil,
            items: key_items.fetch(i, []).map { |name, key| item(b, i, name, key) },
            hidden: hidden_items.fetch(i, []).map { |args| hidden(b, i, *args) })
        },
        encounters: encounters, trainers: trainers, trades: trades, oak_queue: oak_queue,
        gym: gym, gym_after: gym_after, gym_finale: gym_finale, trivia: trivia, grind: grind
      )
    end

    # Declarative per-item steps: each def is a narrative beat ({}), a visible overworld item
    # ({ item: [name, key], scene:, at: }) whose GB-screen shot names the ball, one or more key
    # items handed over together ({ items: [[name, key], ...] }), or a hidden item
    # ({ hidden: [name, key, scene, pin], at: }) whose found-frame panel carries its own shot.
    #
    # `gift: [slug, key]` claims an NPC gift another stop already flags as locked, naming that
    # stop's `later` entry. A ball resolves its tick from the map pin it shares, but a gift has no
    # pin, so this is what stops the two cards drifting onto separate progress ids.
    def self.build_steps(base, defs, pins = {})
      defs.each_with_index.map do |d, i|
        n = i + 1
        step(base, n, html: d.fetch(:html, false), pins: d.fetch(:pins, {}).merge(pins.fetch(n, {})),
          items: step_items(base, n, d), map: d[:map], dex_seen: d[:dex_seen], line: d[:line],
          hidden: (d[:hidden] ? [ hidden(base, n, *d[:hidden], at: d[:at]) ] : []),
          shot: (d[:scene] ? scene_shot(d[:scene], "STEP #{n}") : nil), link: d[:link])
      end
    end

    def self.step_items(base, n, def_)
      return [ item(base, n, *def_[:item], at: def_[:at]) ] if def_[:item]

      gift = def_[:gift]
      (def_[:items] || []).map { |name, key| item(base, n, name, key, tick: gift && gift_tick(*gift)) }
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
        shot: shot("GYM"), badge: badge, badge_img: badge_img(badge),
        tm: tm, puzzle: puzzle, trainers: trainers, leader: leader
      )
    end

    def self.gstep(slug, n, map: false, scene: nil)
      GymStep.new(n: n, text_key: "#{base(slug)}.gym.puzzle.#{n}",
        shot: gym_shot(n, map, scene))
    end

    def self.gym_shot(n, map, scene)
      return scene_shot(scene, "STEP #{n}") if scene
      return shot("STEP #{n}") if map

      nil
    end

    def self.route_3
      b = base("route-3")
      Location.new(
        slug: "route-3", kind: "ROUTE", name: "Route 3", order: 8, badge: nil,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [ step(b, 1), step(b, 2, pins: { north: "route-3/exit-north" }) ],
        encounters: [
          enc("route-3", "021", "GRASS", "55%", "8–12", "COMMON", "021", "022"),
          enc("route-3", "056", "GRASS", "15%", "9", "UNCOMMON", "056", "057"),
          enc("route-3", "019", "GRASS", "15%", "10–12", "UNCOMMON", "019", "020"),
          enc("route-3", "027", "GRASS", "15%", "8–10", "UNCOMMON", "027", "028")
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
        pins: { 1 => { center: "route-4/exit-11-5" }, 2 => { cave: "route-4/exit-18-5" } },
        trivia: trivia(base("route-4-mt-moon"), anchor: "mt-moon-magikarp",
          shot: scene_shot("mt-moon-magikarp", "MAGIKARP")))
    end

    def self.mt_moon
      loc("mt-moon", "CAVE", "Mt. Moon", 9,
        pins: { 3 => { down: "mt-moon-1f/exit-25-15", lower: "mt-moon-b1f/exit-13-27" },
                7 => { down: "mt-moon-1f/exit-17-11", lower: "mt-moon-b1f/exit-17-11" },
                11 => { down: "mt-moon-1f/exit-5-5", lower: "mt-moon-b1f/exit-21-17" },
                14 => { up: "mt-moon-b2f/exit-5-7", out: "mt-moon-b1f/exit-27-3" } },
        steps: [
          { item: [ "TM Water Gun", "tm-water-gun" ], scene: "mt-moon-item-tm-water-gun" },
          { item: [ "Potion", "potion-2-20" ], scene: "mt-moon-item-potion-2-20", at: [ 2, 20 ] },
          { item: [ "HP Up", "hp-up" ], scene: "mt-moon-item-hp-up", html: true },
          { item: [ "Potion", "potion-20-33" ], scene: "mt-moon-item-potion-20-33", at: [ 20, 33 ] },
          { item: [ "Rare Candy", "rare-candy" ], scene: "mt-moon-item-rare-candy" },
          { item: [ "Escape Rope", "escape-rope" ], scene: "mt-moon-item-escape-rope" },
          { html: true },
          { item: [ "TM Mega Punch", "tm-mega-punch" ], scene: "mt-moon-item-tm-mega-punch" },
          { hidden: [ "Ether", "ether", "mt-moon-hidden-ether", "mt-moon-ether" ] },
          { item: [ "Moon Stone", "moon-stone" ], scene: "mt-moon-item-moon-stone" },
          { html: true },
          { hidden: [ "Moon Stone", "moon-stone", "mt-moon-hidden-moon-stone", "mt-moon-moon-stone" ] },
          { items: [ [ "Fossil", "fossil" ] ], scene: "mt-moon-fossils" },
          { html: true }
        ],
        encounters: [
          enc("mt-moon", "041", "CAVE", "74%", "6–13", "COMMON", "041", "042"),
          enc("mt-moon", "074", "CAVE", "20%", "10–11", "UNCOMMON", "074", "075", "076"),
          enc("mt-moon", "046", "CAVE", "15%", "9–13", "UNCOMMON", "046", "047"),
          enc("mt-moon", "035", "CAVE", "10%", "9–13", "UNCOMMON", "035", "036", tip: true),
          enc("mt-moon", "027", "CAVE", "4%", "12", "RARE", "027", "028")
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
          { scene: "route-4-exit", pins: { exit: "route-4/exit-24-5" } },
          { hidden: [ "Great Ball", "great-ball", "route-4-hidden-great-ball", "route-4-great-ball" ] },
          { item: [ "TM Whirlwind", "tm-whirlwind" ], scene: "route-4-item-tm-whirlwind" },
          { pins: { east: "route-4/exit-east" } }
        ],
        encounters: [
          enc("route-4", "021", "GRASS", "55%", "8–12", "COMMON", "021", "022"),
          enc("route-4", "056", "GRASS", "15%", "9", "UNCOMMON", "056", "057"),
          enc("route-4", "019", "GRASS", "15%", "10–12", "UNCOMMON", "019", "020"),
          enc("route-4", "027", "GRASS", "15%", "8–10", "UNCOMMON", "027", "028"),
          enc("route-4", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("route-4", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("route-4", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("route-4", "118", "SUPER ROD", "90%", "20–30", "COMMON", "118", "119"),
          enc("route-4", "119", "SUPER ROD", "10%", "30", "UNCOMMON", "118", "119")
        ])
    end

    def self.cerulean_city
      loc("cerulean-city", "CITY", "Cerulean City", 11, steps: 4, shots: [ 3, 4 ], gym_after: 3, gym_finale: true, badge: "CASCADE",
        pins: { 1 => { center: "cerulean-city/exit-19-17", mart: "cerulean-city/exit-25-25", gym: "cerulean-city/exit-30-19" },
                2 => { door: "cerulean-city/exit-9-11" },
                3 => { house: "cerulean-city/exit-13-15", north: "cerulean-city/exit-north" } },
        hidden_items: { 2 => [ [ "Rare Candy", "rare_candy", "cerulean-city-hidden-rare-candy", "cerulean-rare-candy" ] ] },
        key_items: { 3 => [ [ "Bicycle", "bicycle" ] ] },
        encounters: [
          enc("cerulean-city", "001", "GIFT", "-", "10", "GIFT", "001", "002", "003", tip: true, from: true, unlock: "pokemon/yellow/025.png"),
          enc("cerulean-city", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("cerulean-city", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("cerulean-city", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("cerulean-city", "118", "SUPER ROD", "70%", "25–30", "COMMON", "118", "119"),
          enc("cerulean-city", "119", "SUPER ROD", "30%", "30–40", "COMMON", "118", "119")
        ],
        trainers: [],
        gym: gym("cerulean-city", "Cerulean Gym", "WATER", "CASCADE", "TM11 · BUBBLEBEAM",
          leader("Misty", 2079, mon("120", 18), mon("121", 21), battle: scene_shot("battle-misty", "BATTLE"), opp: [ "MISTY", 1 ])),
        oak_queue: [ oak("cerulean-city", "001", 1) ])
    end

    def self.route_24
      loc("route-24", "ROUTE", "Route 24", 12, steps: [
          {},
          {},
          { scene: "route-24-charmander", pins: { boy: "route-24/npc-charmander" } },
          { item: [ "TM Thunder Wave", "tm-thunder-wave" ], scene: "route-24-item-tm-thunder-wave" },
          { pins: { east: "route-24/exit-east" } }
        ],
        encounters: [
          enc("route-24", "043", "GRASS", "30%", "12–14", "COMMON", "043", "044", "045"),
          enc("route-24", "069", "GRASS", "30%", "12–14", "COMMON", "069", "070", "071"),
          enc("route-24", "016", "GRASS", "29%", "13–17", "UNCOMMON", "016", "017", "018"),
          enc("route-24", "048", "GRASS", "10%", "13–16", "UNCOMMON", "048", "049"),
          enc("route-24", "017", "GRASS", "1%", "17", "RARE", "016", "017", "018"),
          enc("route-24", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("route-24", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("route-24", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("route-24", "118", "SUPER ROD", "90%", "20–30", "COMMON", "118", "119"),
          enc("route-24", "119", "SUPER ROD", "10%", "30", "UNCOMMON", "118", "119"),
          enc("route-24", "004", "GIFT", "-", "10", "GIFT", "004", "005", "006", tip: true, from: true)
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
          { item: [ "TM Seismic Toss", "tm-seismic-toss" ], scene: "route-25-item-tm-seismic-toss",
            pins: { guard: "route-25/trainer-24-4" } },
          { hidden: [ "Ether", "ether", "route-25-hidden-ether", "route-25-ether" ] },
          { item: [ "S.S. Ticket", "s_s_ticket" ], scene: "route-25-bill",
            pins: { cottage: "route-25/exit-45-3" } }
        ],
        encounters: [
          enc("route-25", "043", "GRASS", "30%", "12–14", "COMMON", "043", "044", "045"),
          enc("route-25", "069", "GRASS", "30%", "12–14", "COMMON", "069", "070", "071"),
          enc("route-25", "016", "GRASS", "29%", "13–17", "UNCOMMON", "016", "017", "018"),
          enc("route-25", "048", "GRASS", "10%", "13–16", "UNCOMMON", "048", "049"),
          enc("route-25", "017", "GRASS", "1%", "17", "RARE", "016", "017", "018"),
          enc("route-25", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("route-25", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("route-25", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("route-25", "098", "SUPER ROD", "70%", "10–15", "COMMON", "098", "099"),
          enc("route-25", "099", "SUPER ROD", "30%", "15–25", "COMMON", "098", "099")
        ],
        oak_queue: [ oak("route-25", "048", 1) ])
    end

    def self.route_5
      loc("route-5", "ROUTE", "Route 5", 14, steps: 2, shots: [ 2 ],
        pins: { 1 => { daycare: "route-5/exit-10-21" }, 2 => { path: "route-5/exit-17-27" } },
        encounters: [
          enc("route-5", "016", "GRASS", "40%", "15–17", "COMMON", "016", "017", "018"),
          enc("route-5", "019", "GRASS", "30%", "14–16", "COMMON", "019", "020"),
          enc("route-5", "063", "GRASS", "15%", "7", "UNCOMMON", "063", "064", "065"),
          enc("route-5", "039", "GRASS", "10%", "3–7", "UNCOMMON", "039", "040"),
          enc("route-5", "017", "GRASS", "5%", "17", "RARE", "016", "017", "018")
        ],
        trades: [ trade("route-5", "machoke", "104", "067", "RICKY",
          house: "route-5-underground-house", inside: "route-5-underground-house-inside") ],
        oak_queue: [ oak("route-5", "063", 1) ])
    end

    def self.underground_path
      loc("underground-path", "TUNNEL", "Underground Path", 15, steps: [
          { pins: { in: "underground-path/exit-5-4" },
            hidden: [ "Full Restore", "full-restore", "underground-path-hidden-full-restore",
                      "underground-path-full-restore" ] },
          { pins: { out: "underground-path/exit-2-41" },
            hidden: [ "X Special", "x-special", "underground-path-hidden-x-special",
                      "underground-path-x-special" ] }
        ])
    end

    def self.route_6
      loc("route-6", "ROUTE", "Route 6", 16, steps: 2,
        pins: { 1 => { path: "route-6/exit-17-13" }, 2 => { south: "route-6/exit-south" } },
        encounters: [
          enc("route-6", "016", "GRASS", "40%", "15–17", "COMMON", "016", "017", "018"),
          enc("route-6", "019", "GRASS", "30%", "14–16", "COMMON", "019", "020"),
          enc("route-6", "063", "GRASS", "15%", "7", "UNCOMMON", "063", "064", "065"),
          enc("route-6", "039", "GRASS", "10%", "3–7", "UNCOMMON", "039", "040"),
          enc("route-6", "017", "GRASS", "5%", "17", "RARE", "016", "017", "018"),
          enc("route-6", "054", "SURF", "94%", "15", "COMMON", "054", "055"),
          enc("route-6", "055", "SURF", "6%", "15–20", "RARE", "054", "055"),
          enc("route-6", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("route-6", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("route-6", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("route-6", "118", "SUPER ROD", "100%", "5–20", "COMMON", "118", "119")
        ])
    end

    # One shore, listed the same on both passes: the water does not change while you are on the
    # ship, and the Old Rod the first pass hands you only becomes castable on the return.
    def self.vermilion_water
      [
        enc("vermilion-city", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
        enc("vermilion-city", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
        enc("vermilion-city", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
        enc("vermilion-city", "072", "SUPER ROD", "90%", "10–20", "COMMON", "072", "073"),
        enc("vermilion-city", "116", "SUPER ROD", "10%", "5", "UNCOMMON", "116", "117"),
        # The dock is its own map with its own Super Rod slots; these two live only out there.
        enc("vermilion-city", "120", "SUPER ROD", "20%", "15", "UNCOMMON", "120", "121"),
        enc("vermilion-city", "090", "SUPER ROD", "10%", "10", "UNCOMMON", "090", "091")
      ]
    end

    # Vermilion is walked twice, the way Route 4 is walked twice around Mt. Moon. The gym plaza is
    # sealed off by cuttable trees and the Max Ether sits on water, so the first pass can only take
    # the two gifts and board the ship; Surge, the Squirtle he unlocks and the road east all belong
    # to the return trip, once the S.S. Anne has handed over Cut.
    def self.vermilion_city
      b = base("vermilion-city")
      Location.new(
        slug: "vermilion-city", kind: "CITY", name: "Vermilion City", order: 17, badge: nil,
        note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [
          step(b, 1, items: [ item(b, 1, "Bike Voucher", "bike_voucher"), item(b, 1, "Old Rod", "old_rod") ],
            pins: { center: "vermilion-city/exit-11-3", club: "vermilion-city/exit-9-13", guru: "vermilion-city/exit-7-3" }),
          step(b, 2, shot: scene_shot("vermilion-ss-anne-dock", "STEP 2"),
            pins: { gym: "vermilion-city/exit-12-19", dock: "vermilion-city/exit-18-31" },
            link: StepLink.new(leg: "ss-anne", anchor: "ss-anne-step-1"))
        ],
        encounters: vermilion_water,
        trainers: [], oak_queue: [],
        later: [ later("vermilion-city", "max_ether", "Max Ether", "ITEM", "Surf", "vermilion-city-hidden-max-ether") ]
      )
    end

    def self.vermilion_city_return
      b = base("vermilion-city-return")
      Location.new(
        slug: "vermilion-city-return", kind: "CITY", name: "Vermilion City", order: 17,
        badge: "THUNDER", note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [
          step(b, 1, pins: { gym: "vermilion-city/exit-12-19" }),
          step(b, 2, shot: scene_shot("vermilion-squirtle", "STEP 2"),
            pins: { east: "vermilion-city/exit-east" })
        ], gym_after: 1,
        encounters: [ enc("vermilion-city", "007", "GIFT", "-", "10", "GIFT", "007", "008", "009",
          tip: true, from: true, unlock: "walkthrough/yellow/badges/thunder.png",
          badge: "THUNDER") ] + vermilion_water,
        trainers: [],
        gym: gym("vermilion-city", "Vermilion Gym", "ELECTRIC", "THUNDER", "TM24 · THUNDERBOLT",
          leader("Lt. Surge", 2772, mon("026", 28), battle: scene_shot("battle-lt-surge", "BATTLE"), opp: [ "LT_SURGE", 1 ]),
          puzzle: [ gstep("vermilion-city", 1),
                    gstep("vermilion-city", 2, scene: "vermilion-gym-second-switch"),
                    gstep("vermilion-city", 3) ]),
        oak_queue: [ oak("vermilion-city", "007", 1) ]
      )
    end

    def self.ss_anne
      # Straight below to the crew deck, back up through 1F stern to bow, then over 2F to the
      # bow deck and down again, so each floor is swept once and the ship is crossed twice
      # instead of four times.
      loc("ss-anne", "BUILDING", "S.S. Anne", 18, steps: [
          { pins: { down: "ss-anne-1f/exit-37-15", cabin: "ss-anne-b1f/exit-23-3" } },
          { item: [ "Max Potion", "max-potion" ], scene: "ss-anne-item-max-potion" },
          { item: [ "Ether", "ether" ], scene: "ss-anne-item-ether",
            pins: { cabin: "ss-anne-b1f/exit-15-3" } },
          { item: [ "TM Rest", "tm-rest" ], scene: "ss-anne-item-tm-rest",
            pins: { cabin: "ss-anne-b1f/exit-11-3" } },
          { hidden: [ "Hyper Potion", "hyper-potion", "ss-anne-hidden-hyper-potion",
                      "ss-anne-hyper-potion" ],
            pins: { cabin: "ss-anne-b1f/exit-7-3" } },
          { item: [ "TM Body Slam", "tm-body-slam" ], scene: "ss-anne-item-tm-body-slam",
            pins: { up: "ss-anne-b1f/exit-27-5", cabin: "ss-anne-1f/exit-11-8" } },
          { hidden: [ "Great Ball", "great-ball", "ss-anne-hidden-great-ball",
                      "ss-anne-great-ball" ],
            pins: { kitchen: "ss-anne-1f/exit-3-16" } },
          { pins: { up: "ss-anne-1f/exit-2-6", down: "ss-anne-2f/exit-2-12",
                    deck: "ss-anne-3f/exit-0-3" } },
          {},
          { pins: { cabin: "ss-anne-2f/exit-9-11" }, dex_seen: [ "143" ] },
          { item: [ "Max Ether", "max-ether" ], scene: "ss-anne-item-max-ether",
            pins: { cabin: "ss-anne-2f/exit-13-11" } },
          { item: [ "Rare Candy", "rare-candy" ], scene: "ss-anne-item-rare-candy",
            pins: { cabin: "ss-anne-2f/exit-21-11" } },
          {},
          { items: [ [ "HM01 Cut", "hm01_cut" ] ], scene: "ss-anne-cut",
            pins: { stairs: "ss-anne-2f/exit-36-4" },
            link: StepLink.new(leg: "leg-06", anchor: "route-11-step-1") }
        ],
        trainers: [ rival(1300, mon("021", 19), mon("019", 16), mon("027", 18), mon("133", 20),
          where: scene_shot("ss-anne-rival", "WHERE"),
          battle: scene_shot("battle-rival-ss-anne", "BATTLE"), opp: [ "RIVAL1", 1 ]) ])
    end

    def self.route_11
      loc("route-11", "ROUTE", "Route 11", 19, steps: [
          { pins: { cave: "route-11/exit-4-5" } },
          {},
          { hidden: [ "Escape Rope", "escape-rope", "route-11-hidden-escape-rope", "route-11-escape-rope" ] },
          { items: [ [ "Itemfinder", "itemfinder" ] ], pins: { gate: "route-11/exit-49-8" } },
          { pins: { west: "route-11/exit-west" },
            link: StepLink.new(leg: "leg-06", anchor: "vermilion-city-return-step-1") }
        ],
        encounters: [
          enc("route-11", "016", "GRASS", "35%", "16–18", "COMMON", "016", "017", "018"),
          enc("route-11", "019", "GRASS", "30%", "15–17", "COMMON", "019", "020"),
          enc("route-11", "096", "GRASS", "24%", "15–19", "UNCOMMON", "096", "097"),
          enc("route-11", "017", "GRASS", "10%", "18–20", "UNCOMMON", "016", "017", "018"),
          enc("route-11", "020", "GRASS", "1%", "17", "RARE", "019", "020"),
          enc("route-11", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("route-11", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("route-11", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("route-11", "072", "SUPER ROD", "90%", "10–20", "COMMON", "072", "073"),
          enc("route-11", "116", "SUPER ROD", "10%", "5", "UNCOMMON", "116", "117")
        ],
        trades: [ trade("route-11", "dugtrio", "108", "051", "GURIO",
          house: "route-11-gate", inside: "route-11-gate-inside") ],
        oak_queue: [ oak("route-11", "096", 1) ])
    end

    # The tunnel is two screens of Diglett, but its north door is the back way into the half of
    # Route 2 that Cut walled off on the first pass. So the stop is the whole loop: out at the top,
    # down the east side for Flash, the Mr. Mime trade, the Moon Stone and the HP Up, on into
    # Viridian for the Dream Eater TM, then back through the tunnel for Cerulean. Route 2 and
    # Viridian City lend their maps (MAP_EXTRA) so every pin the detour names is on this page.
    # Shared by the encounter cards and the grind spot, which reads the same rates and level bands
    # rather than repeating them.
    def self.digletts_cave_encounters
      @digletts_cave_encounters ||= [
        enc("digletts-cave", "050", "CAVE", "94%", "15–22", "COMMON", "050", "051"),
        enc("digletts-cave", "051", "CAVE", "6%", "29–31", "RARE", "050", "051")
      ].freeze
    end

    def self.digletts_cave
      loc("digletts-cave", "CAVE", "Diglett's Cave", 20,
        title: "Diglett's Cave → Viridian Detour", steps: [
          { map: "digletts-cave", pins: { south: "digletts-cave/exit-37-31" } },
          { map: "digletts-cave" },
          { map: "digletts-cave", scene: "route-2-digletts-exit",
            pins: { north: "digletts-cave/exit-5-5" } },
          { map: "route-2", pins: { house: "route-2/exit-15-19" } },
          { map: "route-2", scene: "route-2-cut-tree", pins: { gate: "route-2/exit-16-35" } },
          { map: "route-2", items: [ [ "HM05 Flash", "flash" ] ], gift: %w[route-2 flash],
            scene: "route-2-flash" },
          { map: "route-2", item: [ "HP Up", "hp-up" ], scene: "route-2-hp-up" },
          { map: "route-2", item: [ "Moon Stone", "moon-stone" ], scene: "route-2-moon-stone" },
          { map: "route-2", scene: "route-2-viridian-cut", pins: { south: "route-2/exit-south" } },
          { map: "viridian-city", items: [ [ "TM42 Dream Eater", "tm42" ] ],
            gift: %w[viridian-city tm42], scene: "viridian-city-tm42-gift",
            pins: { fisher: "viridian-city/npc-tm42" } },
          { map: "pewter-city", scene: "route-2-pewter-cut" },
          { map: "pewter-city", scene: "pewter-museum-cut",
            pins: { museum: "pewter-city/exit-19-5" } },
          { map: "pewter-city", item: [ "Old Amber", "old-amber" ], scene: "museum-old-amber" },
          { html: true, link: StepLink.new(leg: "leg-07", anchor: "route-9-step-1") }
        ],
        encounters: [
          *digletts_cave_encounters
        ],
        trades: [ trade("route-2", "mr_mime", "035", "122", "MILES",
          house: "route-2-trade-house", inside: "route-2-trade-house-inside",
          tick: "route-2/trade-0") ],
        oak_queue: [ oak("digletts-cave", "050", 1) ],
        grind: grind_spot(base("digletts-cave"), anchor: "diglett-grinding",
          after_map: "digletts-cave", art: "walkthrough/art/dugtrio.png",
          note_icon: "walkthrough/items/repel.png",
          encounters: digletts_cave_encounters,
          mons: [ [ "050", "common", 20 ], [ "051", "rare", 30 ] ]))
    end

    def self.pokemon_tower
      loc("pokemon-tower", "DUNGEON", "Pokémon Tower", 30, steps: [
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
          enc("pokemon-tower", "092", "FLOORS", "94%", "18–29", "COMMON", "092", "093", "094", tip: true),
          enc("pokemon-tower", "093", "FLOORS", "6%", "20–29", "RARE", "092", "093", "094"),
          enc("pokemon-tower", "104", "FLOORS", "5%", "20–24", "RARE", "104", "105")
        ],
        trainers: [
          tr("TEAM ROCKET", "Jessie & James", 810,
            mon("052", 27), mon("024", 27), mon("110", 27),
            where: scene_shot("pokemon-tower-jessie-james", "WHERE"),
            battle: scene_shot("battle-pokemon-tower-jessie-james", "BATTLE"))
        ],
        oak_queue: [ oak("pokemon-tower", "092", 1), oak("pokemon-tower", "104", 1) ])
    end

    def self.route_12
      loc("route-12", "ROUTE", "Route 12", 31, steps: [
          { pins: { gate: "route-12/exit-10-21" } },
          { item: [ "TM Pay Day", "tm-pay-day" ], scene: "route-12-item-tm-pay-day" },
          { scene: "route-12-snorlax" },
          { hidden: [ "Hyper Potion", "hyper-potion", "route-12-hidden-hyper-potion", "route-12-hyper-potion" ] },
          { items: [ [ "Super Rod", "super_rod" ] ], pins: { guru: "route-12/exit-11-77" } },
          { item: [ "Iron", "iron" ], scene: "route-12-item-iron" },
          { pins: { south: "route-12/exit-south" } }
        ],
        encounters: [
          enc("route-12", "043", "GRASS", "30%", "25–27", "COMMON", "043", "044", "045"),
          enc("route-12", "069", "GRASS", "30%", "25–27", "COMMON", "069", "070", "071"),
          enc("route-12", "016", "GRASS", "15%", "28", "UNCOMMON", "016", "017", "018"),
          enc("route-12", "017", "GRASS", "10%", "28", "UNCOMMON", "016", "017", "018"),
          enc("route-12", "083", "GRASS", "6%", "26–31", "RARE", "083", tip: true),
          enc("route-12", "044", "GRASS", "5%", "29", "RARE", "043", "044", "045"),
          enc("route-12", "070", "GRASS", "5%", "29", "RARE", "069", "070", "071"),
          enc("route-12", "079", "SURF", "94%", "15", "COMMON", "079", "080"),
          enc("route-12", "080", "SURF", "6%", "15–20", "RARE", "079", "080"),
          enc("route-12", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("route-12", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("route-12", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("route-12", "116", "SUPER ROD", "70%", "20–25", "COMMON", "116", "117"),
          enc("route-12", "117", "SUPER ROD", "30%", "25–35", "COMMON", "116", "117"),
          enc("route-12", "143", "STATIC", "-", "30", "STATIC", "143", tip: true)
        ],
        oak_queue: [ oak("route-12", "079", 1), oak("route-12", "083", 1) ])
    end

    def self.route_13
      loc("route-13", "ROUTE", "Route 13", 32, steps: [
          {},
          { hidden: [ "Calcium", "calcium", "route-13-hidden-calcium", "route-13-calcium" ] },
          { hidden: [ "PP Up", "pp-up", "route-13-hidden-pp-up", "route-13-pp-up" ] },
          { pins: { west: "route-13/exit-west" } }
        ],
        encounters: [
          enc("route-13", "043", "GRASS", "30%", "25–27", "COMMON", "043", "044", "045"),
          enc("route-13", "069", "GRASS", "30%", "25–27", "COMMON", "069", "070", "071"),
          enc("route-13", "017", "GRASS", "15%", "28", "UNCOMMON", "016", "017", "018"),
          enc("route-13", "016", "GRASS", "10%", "28", "UNCOMMON", "016", "017", "018"),
          enc("route-13", "083", "GRASS", "6%", "26–31", "RARE", "083"),
          enc("route-13", "044", "GRASS", "5%", "29", "RARE", "043", "044", "045"),
          enc("route-13", "070", "GRASS", "5%", "29", "RARE", "069", "070", "071"),
          enc("route-13", "079", "SURF", "94%", "15", "COMMON", "079", "080"),
          enc("route-13", "080", "SURF", "6%", "15–20", "RARE", "079", "080"),
          enc("route-13", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("route-13", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("route-13", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("route-13", "116", "SUPER ROD", "70%", "15–20", "COMMON", "116", "117"),
          enc("route-13", "072", "SUPER ROD", "20%", "10", "UNCOMMON", "072", "073"),
          enc("route-13", "117", "SUPER ROD", "10%", "20", "UNCOMMON", "116", "117")
        ],
        oak_queue: [ oak("route-13", "132", 1) ])
    end

    def self.route_14
      loc("route-14", "ROUTE", "Route 14", 33, steps: 2, pins: { 2 => { west: "route-14/exit-west" } },
        encounters: [
          enc("route-14", "043", "GRASS", "30%", "26–28", "COMMON", "043", "044", "045"),
          enc("route-14", "069", "GRASS", "30%", "26–28", "COMMON", "069", "070", "071"),
          enc("route-14", "048", "GRASS", "20%", "24–27", "UNCOMMON", "048", "049"),
          enc("route-14", "017", "GRASS", "10%", "30", "UNCOMMON", "016", "017", "018"),
          enc("route-14", "044", "GRASS", "5%", "30", "RARE", "043", "044", "045"),
          enc("route-14", "070", "GRASS", "5%", "30", "RARE", "069", "070", "071"),
          enc("route-14", "049", "GRASS", "1%", "30", "RARE", "048", "049")
        ])
    end

    def self.route_15
      loc("route-15", "ROUTE", "Route 15", 34, steps: [
          { items: [ [ "Exp. All", "exp_all" ] ], pins: { east: "route-15/exit-east" } },
          { item: [ "TM Rage", "tm-rage" ], scene: "route-15-item-tm-rage" },
          { pins: { gate: "route-15/exit-7-8", west: "route-15/exit-west" } }
        ],
        encounters: [
          enc("route-15", "043", "GRASS", "30%", "26–28", "COMMON", "043", "044", "045"),
          enc("route-15", "069", "GRASS", "30%", "26–28", "COMMON", "069", "070", "071"),
          enc("route-15", "048", "GRASS", "20%", "24–27", "UNCOMMON", "048", "049"),
          enc("route-15", "017", "GRASS", "10%", "32", "UNCOMMON", "016", "017", "018"),
          enc("route-15", "044", "GRASS", "5%", "30", "RARE", "043", "044", "045"),
          enc("route-15", "070", "GRASS", "5%", "30", "RARE", "069", "070", "071"),
          enc("route-15", "049", "GRASS", "1%", "30", "RARE", "048", "049")
        ])
    end

    def self.fuchsia_city
      loc("fuchsia-city", "CITY", "Fuchsia City", 35, steps: 4, gym_after: 3, gym_finale: true, badge: "SOUL",
        pins: { 1 => { center: "fuchsia-city/exit-19-27", mart: "fuchsia-city/exit-5-13", gym: "fuchsia-city/exit-5-27" },
                3 => { safari: "fuchsia-city/exit-18-3" },
                4 => { warden: "fuchsia-city/exit-27-27" } },
        key_items: { 2 => [ [ "Good Rod", "good_rod" ] ], 4 => [ [ "HM04 Strength", "hm04_strength" ] ] },
        encounters: [
          enc("fuchsia-city", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("fuchsia-city", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("fuchsia-city", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("fuchsia-city", "129", "SUPER ROD", "90%", "5–15", "COMMON", "129", "130"),
          enc("fuchsia-city", "130", "SUPER ROD", "10%", "15", "UNCOMMON", "129", "130", tip: true)
        ],
        trainers: [],
        gym: gym("fuchsia-city", "Fuchsia Gym", "POISON", "SOUL", "TM06 · TOXIC",
          leader("Koga", 4950, mon("048", 44), mon("048", 46), mon("048", 48), mon("049", 50), battle: scene_shot("battle-koga", "BATTLE"), opp: [ "KOGA", 1 ]),
          puzzle: [ gstep("fuchsia-city", 1), gstep("fuchsia-city", 2, map: true), gstep("fuchsia-city", 3) ]),
        oak_queue: [ oak("fuchsia-city", "130", 1) ])
    end

    def self.safari_zone
      loc("safari-zone", "DUNGEON", "Safari Zone", 36, steps: [
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
          enc("safari-zone", "102", "SAFARI", "20%", "20–26", "UNCOMMON", "102", "103"),
          enc("safari-zone", "029", "SAFARI", "20%", "14–36", "UNCOMMON", "029", "030", "031"),
          enc("safari-zone", "032", "SAFARI", "20%", "14–36", "UNCOMMON", "032", "033", "034"),
          enc("safari-zone", "047", "SAFARI", "15%", "27–32", "UNCOMMON", "046", "047"),
          enc("safari-zone", "115", "SAFARI", "15%", "28–33", "UNCOMMON", "115", tip: true),
          enc("safari-zone", "030", "SAFARI", "10%", "23–32", "UNCOMMON", "029", "030", "031"),
          enc("safari-zone", "033", "SAFARI", "10%", "23–32", "UNCOMMON", "032", "033", "034"),
          enc("safari-zone", "104", "SAFARI", "10%", "16–19", "UNCOMMON", "104", "105"),
          enc("safari-zone", "111", "SAFARI", "10%", "20–25", "UNCOMMON", "111", "112"),
          enc("safari-zone", "128", "SAFARI", "10%", "21", "UNCOMMON", "128"),
          enc("safari-zone", "046", "SAFARI", "5%", "27", "RARE", "046", "047"),
          enc("safari-zone", "105", "SAFARI", "5%", "24", "RARE", "104", "105"),
          enc("safari-zone", "113", "SAFARI", "4%", "7–21", "RARE", "113", tip: true),
          enc("safari-zone", "114", "SAFARI", "4%", "22–27", "RARE", "114"),
          enc("safari-zone", "123", "SAFARI", "4%", "15–25", "RARE", "123", tip: true),
          enc("safari-zone", "127", "SAFARI", "4%", "15–25", "RARE", "127", tip: true),
          enc("safari-zone", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("safari-zone", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("safari-zone", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("safari-zone", "129", "SUPER ROD", "90%", "5–15", "COMMON", "129", "130"),
          enc("safari-zone", "147", "SUPER ROD", "20%", "10–15", "UNCOMMON", "147", "148", "149", tip: true),
          enc("safari-zone", "148", "SUPER ROD", "10%", "15", "UNCOMMON", "147", "148", "149")
        ],
        oak_queue: [
          oak("safari-zone", "123", 1), oak("safari-zone", "127", 1),
          oak("safari-zone", "147", 1), oak("safari-zone", "115", 1)
        ])
    end

    def self.route_16
      loc("route-16", "ROUTE", "Route 16", 37, steps: 3, shots: [ 2 ],
        pins: { 1 => { house: "route-16/exit-7-5" }, 2 => { gate: "route-16/exit-17-10" },
                3 => { gate: "route-16/exit-17-4", south: "route-16/exit-south" } },
        key_items: { 1 => [ [ "HM02 Fly", "hm02_fly" ] ] },
        encounters: [
          enc("route-16", "084", "GRASS", "40%", "22–26", "COMMON", "084", "085"),
          enc("route-16", "019", "GRASS", "25%", "23–24", "UNCOMMON", "019", "020"),
          enc("route-16", "021", "GRASS", "25%", "22–23", "UNCOMMON", "021", "022"),
          enc("route-16", "020", "GRASS", "6%", "25–26", "RARE", "019", "020"),
          enc("route-16", "022", "GRASS", "5%", "24", "RARE", "021", "022"),
          enc("route-16", "143", "STATIC", "-", "30", "STATIC", "143", tip: true)
        ],
        oak_queue: [ oak("route-16", "084", 1), oak("route-16", "143", 1) ])
    end

    def self.route_17
      loc("route-17", "ROUTE", "Route 17", 38, steps: [
          { pins: { north: "route-17/exit-north" } },
          { hidden: [ "Rare Candy", "rare-candy", "route-17-hidden-rare-candy", "route-17-rare-candy" ] },
          { hidden: [ "Full Restore", "full-restore", "route-17-hidden-full-restore", "route-17-full-restore" ] },
          { hidden: [ "PP Up", "pp-up", "route-17-hidden-pp-up", "route-17-pp-up" ] },
          { hidden: [ "Max Revive", "max-revive", "route-17-hidden-max-revive", "route-17-max-revive" ] },
          { hidden: [ "Max Elixir", "max-elixir", "route-17-hidden-max-elixir", "route-17-max-elixir" ] },
          { pins: { south: "route-17/exit-south" } }
        ],
        encounters: [
          enc("route-17", "084", "GRASS", "50%", "26–28", "COMMON", "084", "085"),
          enc("route-17", "022", "GRASS", "25%", "27–29", "UNCOMMON", "021", "022"),
          enc("route-17", "077", "GRASS", "24%", "28–32", "UNCOMMON", "077", "078"),
          enc("route-17", "085", "GRASS", "1%", "29", "RARE", "084", "085"),
          enc("route-17", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("route-17", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("route-17", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("route-17", "072", "SUPER ROD", "70%", "5–15", "COMMON", "072", "073"),
          enc("route-17", "090", "SUPER ROD", "30%", "25–35", "COMMON", "090", "091")
        ],
        oak_queue: [ oak("route-17", "077", 1) ])
    end

    def self.route_18
      loc("route-18", "ROUTE", "Route 18", 39, steps: 2,
        pins: { 2 => { gate: "route-18/exit-33-8", east: "route-18/exit-east" } },
        encounters: [
          enc("route-18", "084", "GRASS", "40%", "22–26", "COMMON", "084", "085"),
          enc("route-18", "019", "GRASS", "25%", "23–24", "UNCOMMON", "019", "020"),
          enc("route-18", "021", "GRASS", "25%", "22–23", "UNCOMMON", "021", "022"),
          enc("route-18", "020", "GRASS", "6%", "25–26", "RARE", "019", "020"),
          enc("route-18", "022", "GRASS", "5%", "24", "RARE", "021", "022"),
          enc("route-18", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("route-18", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("route-18", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("route-18", "090", "SUPER ROD", "60%", "20–40", "COMMON", "090", "091"),
          enc("route-18", "072", "SUPER ROD", "40%", "15", "COMMON", "072", "073")
        ],
        trades: [ trade("route-18", "parasect", "114", "047", "SPIKE",
          house: "route-18-gate", inside: "route-18-gate-inside") ])
    end

    def self.saffron_city
      loc("saffron-city", "CITY", "Saffron City", 41, steps: 3, gym_after: 2, badge: "MARSH",
        pins: { 2 => { gym: "saffron-city/exit-34-3", silph: "saffron-city/exit-18-21" },
                3 => { dojo: "saffron-city/exit-26-3" } },
        trainers: [ tr("BLACK BELT", nil, 925, mon("106", 37), mon("107", 37),
          where: scene_shot("saffron-dojo-master", "WHERE")) ],
        gym: gym("saffron-city", "Saffron Gym", "PSYCHIC", "MARSH", "TM46 · PSYWAVE",
          leader("Sabrina", 4950, mon("063", 50), mon("064", 50), mon("065", 50), battle: scene_shot("battle-sabrina", "BATTLE"), opp: [ "SABRINA", 1 ]),
          puzzle: [ gstep("saffron-city", 1), gstep("saffron-city", 2, map: true), gstep("saffron-city", 3) ]),
        oak_queue: [ oak("saffron-city", "106", 1) ])
    end

    def self.silph_co
      loc("silph-co", "BUILDING", "Silph Co.", 40, steps: [
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
      loc("route-19", "ROUTE", "Route 19", 42, steps: 2, pins: { 2 => { west: "route-19/exit-west" } },
        encounters: [
          enc("route-19", "072", "SURF", "100%", "5–40", "COMMON", "072", "073"),
          enc("route-19", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("route-19", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("route-19", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("route-19", "072", "SUPER ROD", "60%", "15–30", "COMMON", "072", "073"),
          enc("route-19", "120", "SUPER ROD", "30%", "20", "COMMON", "120", "121"),
          enc("route-19", "073", "SUPER ROD", "10%", "30", "UNCOMMON", "072", "073")
        ])
    end

    def self.route_20
      loc("route-20", "ROUTE", "Route 20", 43, steps: 2, pins: { 2 => { east: "route-20/exit-58-9" } },
        encounters: [
          enc("route-20", "072", "SURF", "100%", "5–40", "COMMON", "072", "073"),
          enc("route-20", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("route-20", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("route-20", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("route-20", "073", "SUPER ROD", "40%", "20–40", "COMMON", "072", "073"),
          enc("route-20", "072", "SUPER ROD", "40%", "20", "COMMON", "072", "073"),
          enc("route-20", "120", "SUPER ROD", "20%", "30", "UNCOMMON", "120", "121")
        ])
    end

    def self.seafoam_islands
      loc("seafoam-islands", "CAVE", "Seafoam Islands", 44, steps: [
          {},
          {},
          { hidden: [ "Nugget", "nugget", "seafoam-islands-hidden-nugget", "seafoam-islands-nugget" ] },
          { hidden: [ "Max Elixir", "max-elixir", "seafoam-islands-hidden-max-elixir", "seafoam-islands-max-elixir" ] },
          { scene: "seafoam-articuno" },
          { hidden: [ "Ultra Ball", "ultra-ball", "seafoam-islands-hidden-ultra-ball", "seafoam-islands-ultra-ball" ] },
          {}
        ],
        encounters: [
          enc("seafoam-islands", "041", "CAVE", "44%", "9–45", "COMMON", "041", "042"),
          enc("seafoam-islands", "098", "CAVE", "35%", "25–31", "COMMON", "098", "099"),
          enc("seafoam-islands", "042", "CAVE", "25%", "27–36", "UNCOMMON", "041", "042"),
          enc("seafoam-islands", "086", "CAVE", "20%", "22–32", "UNCOMMON", "086", "087"),
          enc("seafoam-islands", "079", "CAVE", "15%", "28–31", "UNCOMMON", "079", "080"),
          enc("seafoam-islands", "099", "CAVE", "10%", "28–32", "UNCOMMON", "098", "099"),
          enc("seafoam-islands", "087", "CAVE", "6%", "28–34", "RARE", "086", "087"),
          enc("seafoam-islands", "080", "CAVE", "1%", "31", "RARE", "079", "080"),
          enc("seafoam-islands", "072", "SURF", "70%", "20–40", "COMMON", "072", "073"),
          enc("seafoam-islands", "120", "SURF", "30%", "30", "COMMON", "120", "121"),
          enc("seafoam-islands", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("seafoam-islands", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("seafoam-islands", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("seafoam-islands", "120", "SUPER ROD", "40%", "20–40", "COMMON", "120", "121"),
          enc("seafoam-islands", "098", "SUPER ROD", "40%", "25", "COMMON", "098", "099"),
          enc("seafoam-islands", "099", "SUPER ROD", "20%", "35", "UNCOMMON", "098", "099"),
          enc("seafoam-islands", "144", "STATIC", "-", "50", "STATIC", "144", tip: true)
        ],
        oak_queue: [ oak("seafoam-islands", "086", 1), oak("seafoam-islands", "144", 1) ])
    end

    def self.cinnabar_island
      loc("cinnabar-island", "TOWN", "Cinnabar Island", 46, steps: 3, gym_after: 2, badge: "VOLCANO",
        pins: { 1 => { gym: "cinnabar-island/exit-18-3", mansion: "cinnabar-island/exit-6-3" },
                2 => { lab: "cinnabar-island/exit-6-9" } },
        encounters: [
          enc("cinnabar-island", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("cinnabar-island", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("cinnabar-island", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("cinnabar-island", "120", "SUPER ROD", "60%", "10–15", "COMMON", "120", "121"),
          enc("cinnabar-island", "072", "SUPER ROD", "40%", "15–30", "COMMON", "072", "073"),
          enc("cinnabar-island", "138", "FOSSIL", "-", "30", "GIFT", "138", "139", tip: true),
          enc("cinnabar-island", "140", "FOSSIL", "-", "30", "GIFT", "140", "141", tip: true),
          enc("cinnabar-island", "142", "FOSSIL", "-", "30", "GIFT", "142", tip: true)
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
      loc("pokemon-mansion", "BUILDING", "Pokémon Mansion", 47,
        pins: { 5 => { up: "pokemon-mansion-1f/exit-5-10" },
                6 => { up: "pokemon-mansion-2f/exit-7-10" },
                10 => { down: "pokemon-mansion-1f/exit-21-23" } },
        steps: [
          {},
          { item: [ "Carbos", "carbos" ], scene: "pokemon-mansion-item-carbos" },
          { hidden: [ "Moon Stone", "moon-stone", "pokemon-mansion-hidden-moon-stone", "pokemon-mansion-moon-stone" ] },
          { item: [ "Escape Rope", "escape-rope" ], scene: "pokemon-mansion-item-escape-rope" },
          { html: true },
          { item: [ "Calcium", "calcium" ], scene: "pokemon-mansion-item-calcium", html: true },
          { item: [ "Iron", "iron" ], scene: "pokemon-mansion-item-iron" },
          { item: [ "Max Potion", "max-potion" ], scene: "pokemon-mansion-item-max-potion" },
          { hidden: [ "Max Revive", "max-revive", "pokemon-mansion-hidden-max-revive", "pokemon-mansion-max-revive" ] },
          { html: true },
          { item: [ "TM Blizzard", "tm-blizzard" ], scene: "pokemon-mansion-item-tm-blizzard" },
          { item: [ "Full Restore", "full-restore" ], scene: "pokemon-mansion-item-full-restore" },
          { item: [ "Secret Key", "secret-key" ], scene: "pokemon-mansion-item-secret-key" },
          { hidden: [ "Rare Candy", "rare-candy", "pokemon-mansion-hidden-rare-candy", "pokemon-mansion-rare-candy" ] },
          { item: [ "TM Solarbeam", "tm-solarbeam" ], scene: "pokemon-mansion-item-tm-solarbeam" },
          { item: [ "Rare Candy", "rare-candy" ], scene: "pokemon-mansion-item-rare-candy" },
          {}
        ],
        encounters: [
          enc("pokemon-mansion", "020", "FLOORS", "40%", "34–46", "COMMON", "019", "020"),
          enc("pokemon-mansion", "088", "FLOORS", "40%", "23–38", "COMMON", "088", "089"),
          enc("pokemon-mansion", "019", "FLOORS", "30%", "34–43", "COMMON", "019", "020"),
          enc("pokemon-mansion", "058", "FLOORS", "20%", "26–38", "UNCOMMON", "058", "059", tip: true),
          enc("pokemon-mansion", "132", "FLOORS", "10%", "12–24", "UNCOMMON", "132"),
          enc("pokemon-mansion", "089", "FLOORS", "10%", "35–41", "UNCOMMON", "088", "089")
        ],
        oak_queue: [ oak("pokemon-mansion", "037", 1), oak("pokemon-mansion", "058", 1), oak("pokemon-mansion", "126", 1) ])
    end

    def self.viridian_gym
      loc("viridian-gym", "GYM", "Viridian Gym", 49, steps: [
          {},
          { item: [ "Revive", "revive" ], scene: "viridian-gym-item-revive" },
          {},
          { pins: { out: "viridian-gym/exit-16-17" } }
        ], gym_after: 1, badge: "EARTH",
        gym: gym("viridian-gym", "Viridian Gym", "GROUND", "EARTH", "TM27 · FISSURE",
          leader("Giovanni", 5445, mon("051", 50), mon("053", 53), mon("031", 53), mon("034", 55), mon("112", 55), battle: scene_shot("battle-giovanni-viridian", "BATTLE"), opp: [ "GIOVANNI", 3 ]),
          puzzle: [ gstep("viridian-gym", 1), gstep("viridian-gym", 2), gstep("viridian-gym", 3, map: true) ]))
    end

    def self.victory_road
      loc("victory-road", "CAVE", "Victory Road", 50,
        pins: { 4 => { up: "victory-road-1f/exit-1-1" },
                12 => { up: "victory-road-2f/exit-23-7" },
                15 => { down: "victory-road-2f/exit-23-7", out: "victory-road-2f/exit-29-7" } },
        steps: [
          {},
          { item: [ "Rare Candy", "rare-candy" ], scene: "victory-road-item-rare-candy" },
          { item: [ "TM Sky Attack", "tm-sky-attack" ], scene: "victory-road-item-tm-sky-attack" },
          { html: true },
          { hidden: [ "Ultra Ball", "ultra-ball", "victory-road-hidden-ultra-ball", "victory-road-ultra-ball" ] },
          { item: [ "Guard Spec", "guard-spec" ], scene: "victory-road-item-guard-spec" },
          { scene: "victory-road-moltres" },
          { item: [ "TM Mega Kick", "tm-mega-kick" ], scene: "victory-road-item-tm-mega-kick" },
          { item: [ "Full Heal", "full-heal" ], scene: "victory-road-item-full-heal" },
          { hidden: [ "Full Restore", "full-restore", "victory-road-hidden-full-restore", "victory-road-full-restore" ] },
          { item: [ "TM Submission", "tm-submission" ], scene: "victory-road-item-tm-submission" },
          { html: true },
          { item: [ "Max Revive", "max-revive" ], scene: "victory-road-item-max-revive" },
          { item: [ "TM Explosion", "tm-explosion" ], scene: "victory-road-item-tm-explosion" },
          { html: true }
        ],
        encounters: [
          enc("victory-road", "074", "CAVE", "65%", "26–46", "COMMON", "074", "075", "076"),
          enc("victory-road", "042", "CAVE", "20%", "39–44", "UNCOMMON", "041", "042"),
          enc("victory-road", "041", "CAVE", "20%", "39–44", "UNCOMMON", "041", "042"),
          enc("victory-road", "075", "CAVE", "15%", "41–47", "UNCOMMON", "074", "075", "076"),
          enc("victory-road", "067", "CAVE", "10%", "39–45", "UNCOMMON", "066", "067", "068"),
          enc("victory-road", "095", "CAVE", "10%", "43–49", "UNCOMMON", "095"),
          enc("victory-road", "146", "STATIC", "-", "50", "STATIC", "146", tip: true)
        ],
        oak_queue: [ oak("victory-road", "146", 1) ])
    end

    def self.route_23
      loc("route-23", "ROUTE", "Route 23", 51, steps: [
          { pins: { gate: "route-23/exit-south" } },
          { hidden: [ "Max Ether", "max-ether", "route-23-hidden-max-ether", "route-23-max-ether" ] },
          { hidden: [ "Ultra Ball", "ultra-ball", "route-23-hidden-ultra-ball", "route-23-ultra-ball" ] },
          { hidden: [ "Full Restore", "full-restore", "route-23-hidden-full-restore", "route-23-full-restore" ] },
          { pins: { victory: "route-23/exit-4-31" } }
        ],
        encounters: [
          enc("route-23", "030", "GRASS", "30%", "41–44", "COMMON", "029", "030", "031"),
          enc("route-23", "033", "GRASS", "30%", "41–44", "COMMON", "032", "033", "034"),
          enc("route-23", "056", "GRASS", "20%", "36–41", "UNCOMMON", "056", "057"),
          enc("route-23", "022", "GRASS", "15%", "40–45", "UNCOMMON", "021", "022"),
          enc("route-23", "057", "GRASS", "6%", "41–46", "RARE", "056", "057"),
          enc("route-23", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("route-23", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("route-23", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("route-23", "060", "SUPER ROD", "70%", "25–30", "COMMON", "060", "061", "062"),
          enc("route-23", "061", "SUPER ROD", "30%", "30–40", "COMMON", "060", "061", "062")
        ])
    end

    def self.indigo_plateau
      loc("indigo-plateau", "BUILDING", "Indigo Plateau", 52, steps: 3,
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
      loc("cerulean-cave", "CAVE", "Cerulean Cave", 53,
        pins: { 7 => { up: "cerulean-cave-1f/exit-1-3" },
                13 => { down: "cerulean-cave-2f/exit-3-11", lower: "cerulean-cave-1f/exit-0-6" } },
        steps: [
          {},
          { item: [ "Rare Candy", "rare-candy-29-16" ], scene: "cerulean-cave-item-rare-candy-29-16", at: [ 29, 16 ] },
          { item: [ "Max Revive", "max-revive-29-9" ], scene: "cerulean-cave-item-max-revive-29-9", at: [ 29, 9 ] },
          { hidden: [ "PP Up", "pp-up-18-7", "cerulean-cave-hidden-pp-up-18-7", "cerulean-cave-pp-up-18-7" ], at: [ 18, 7 ] },
          { item: [ "Ultra Ball", "ultra-ball-18-3" ], scene: "cerulean-cave-item-ultra-ball-18-3", at: [ 18, 3 ] },
          { item: [ "Max Elixir", "max-elixir-7-11" ], scene: "cerulean-cave-item-max-elixir-7-11", at: [ 7, 11 ] },
          { html: true },
          { item: [ "Rare Candy", "rare-candy-0-11" ], scene: "cerulean-cave-item-rare-candy-0-11", at: [ 0, 11 ] },
          { item: [ "Ultra Ball", "ultra-ball-16-7" ], scene: "cerulean-cave-item-ultra-ball-16-7", at: [ 16, 7 ] },
          { hidden: [ "PP Up", "pp-up-16-13", "cerulean-cave-hidden-pp-up-16-13", "cerulean-cave-pp-up-16-13" ], at: [ 16, 13 ] },
          { item: [ "Max Revive", "max-revive-19-11" ], scene: "cerulean-cave-item-max-revive-19-11", at: [ 19, 11 ] },
          { item: [ "Full Restore", "full-restore" ], scene: "cerulean-cave-item-full-restore" },
          { html: true },
          { item: [ "Ultra Ball", "ultra-ball-2-13" ], scene: "cerulean-cave-item-ultra-ball-2-13", at: [ 2, 13 ] },
          { item: [ "Max Revive", "max-revive-3-13" ], scene: "cerulean-cave-item-max-revive-3-13", at: [ 3, 13 ] },
          { hidden: [ "PP Up", "pp-up-8-14", "cerulean-cave-hidden-pp-up-8-14", "cerulean-cave-pp-up-8-14" ], at: [ 8, 14 ] },
          { item: [ "Max Elixir", "max-elixir-15-3" ], scene: "cerulean-cave-item-max-elixir-15-3", at: [ 15, 3 ] },
          { item: [ "Ultra Ball", "ultra-ball-26-1" ], scene: "cerulean-cave-item-ultra-ball-26-1", at: [ 26, 1 ] },
          {},
          { scene: "cerulean-cave-mewtwo" }
        ],
        encounters: [
          enc("cerulean-cave", "042", "CAVE", "40%", "50–59", "COMMON", "041", "042"),
          enc("cerulean-cave", "075", "CAVE", "15%", "45–55", "UNCOMMON", "074", "075", "076"),
          enc("cerulean-cave", "132", "CAVE", "15%", "55–65", "UNCOMMON", "132"),
          enc("cerulean-cave", "028", "CAVE", "10%", "52–56", "UNCOMMON", "027", "028"),
          enc("cerulean-cave", "044", "CAVE", "10%", "55–58", "UNCOMMON", "043", "044", "045"),
          enc("cerulean-cave", "070", "CAVE", "10%", "55–58", "UNCOMMON", "069", "070", "071"),
          enc("cerulean-cave", "111", "CAVE", "10%", "50–52", "UNCOMMON", "111", "112"),
          enc("cerulean-cave", "112", "CAVE", "10%", "58–62", "UNCOMMON", "111", "112"),
          enc("cerulean-cave", "108", "CAVE", "6%", "50–55", "RARE", "108", tip: true),
          enc("cerulean-cave", "047", "CAVE", "5%", "54", "RARE", "046", "047"),
          enc("cerulean-cave", "049", "CAVE", "5%", "54", "RARE", "048", "049"),
          enc("cerulean-cave", "113", "CAVE", "5%", "56", "RARE", "113"),
          enc("cerulean-cave", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("cerulean-cave", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("cerulean-cave", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("cerulean-cave", "119", "SUPER ROD", "60%", "35–60", "COMMON", "118", "119"),
          enc("cerulean-cave", "118", "SUPER ROD", "40%", "25–30", "COMMON", "118", "119"),
          enc("cerulean-cave", "150", "STATIC", "-", "70", "STATIC", "150", tip: true)
        ],
        oak_queue: [ oak("cerulean-cave", "150", 1), oak("cerulean-cave", "113", 1) ])
    end

    def self.route_9
      loc("route-9", "ROUTE", "Route 9", 21, steps: [
          {},
          { item: [ "TM Teleport", "tm-teleport" ], scene: "route-9-item-tm-teleport" },
          { hidden: [ "Ether", "ether", "route-9-hidden-ether", "route-9-ether" ] },
          { pins: { east: "route-9/exit-east" } }
        ],
        encounters: [
          enc("route-9", "029", "GRASS", "30%", "16–18", "COMMON", "029", "030", "031"),
          enc("route-9", "032", "GRASS", "30%", "16–18", "COMMON", "032", "033", "034"),
          enc("route-9", "019", "GRASS", "15%", "18", "UNCOMMON", "019", "020"),
          enc("route-9", "021", "GRASS", "10%", "17", "UNCOMMON", "021", "022"),
          enc("route-9", "030", "GRASS", "5%", "18", "RARE", "029", "030", "031"),
          enc("route-9", "033", "GRASS", "5%", "18", "RARE", "032", "033", "034"),
          enc("route-9", "020", "GRASS", "4%", "20", "RARE", "019", "020"),
          enc("route-9", "022", "GRASS", "1%", "19", "RARE", "021", "022")
        ])
    end

    def self.route_10
      loc("route-10", "ROUTE", "Route 10", 22, steps: [
          { scene: "route-10-rock-tunnel", pins: { center: "route-10/exit-11-19", north: "route-10/exit-8-17" } },
          { hidden: [ "Super Potion", "super-potion", "route-10-hidden-super-potion", "route-10-super-potion" ] },
          {},
          { pins: { north: "route-10/exit-8-17" } }
        ],
        encounters: [
          enc("route-10", "081", "GRASS", "50%", "16–22", "COMMON", "081", "082"),
          enc("route-10", "019", "GRASS", "20%", "18", "UNCOMMON", "019", "020"),
          enc("route-10", "029", "GRASS", "10%", "17", "UNCOMMON", "029", "030", "031"),
          enc("route-10", "032", "GRASS", "10%", "17", "UNCOMMON", "032", "033", "034"),
          enc("route-10", "066", "GRASS", "6%", "16–18", "RARE", "066", "067", "068"),
          enc("route-10", "020", "GRASS", "5%", "20", "RARE", "019", "020"),
          enc("route-10", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("route-10", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("route-10", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("route-10", "098", "SUPER ROD", "70%", "15–20", "COMMON", "098", "099"),
          enc("route-10", "116", "SUPER ROD", "20%", "10", "UNCOMMON", "116", "117"),
          enc("route-10", "099", "SUPER ROD", "10%", "25", "UNCOMMON", "098", "099")
        ],
        oak_queue: [ oak("route-10", "081", 1) ])
    end

    # Rock Tunnel splits Route 10 in two, so the guide walks it twice: the Poké Center and the
    # north mouth on the way in, the road to Lavender once you surface at the south mouth. The
    # south half borrows the north half's map (MAP_SOURCE), so both pages hand the reader the same
    # markers and the same ticks.
    def self.route_10_south
      loc("route-10-south", "ROUTE", "Route 10", 22, steps: [
          { hidden: [ "Max Ether", "max-ether", "route-10-hidden-max-ether", "route-10-max-ether" ],
            pins: { south: "route-10/exit-8-53" } },
          { pins: { lavender: "route-10/exit-south" } }
        ])
    end

    def self.rock_tunnel
      # 1F is three regions with no path between them: the north mouth reaches only ladder 1, and
      # the south mouth only the ladder you come back up. B1F is the one floor that joins them, so
      # the crossing is forced rather than chosen, and the middle pair of 1F ladders leads to a
      # trainer pocket holding nothing.
      loc("rock-tunnel", "CAVE", "Rock Tunnel", 23,
        pins: { 2 => { down: "rock-tunnel-1f/exit-37-3" }, 3 => { up: "rock-tunnel-b1f/exit-3-3" } },
        steps: [
          { scene: "rock-tunnel-flash" },
          { html: true },
          { html: true },
          {}
        ],
        encounters: [
          enc("rock-tunnel", "041", "CAVE", "50%", "15–22", "COMMON", "041", "042"),
          enc("rock-tunnel", "074", "CAVE", "40%", "16–21", "COMMON", "074", "075", "076"),
          enc("rock-tunnel", "066", "CAVE", "20%", "17–21", "UNCOMMON", "066", "067", "068"),
          enc("rock-tunnel", "095", "CAVE", "10%", "14–22", "UNCOMMON", "095")
        ],
        oak_queue: [ oak("rock-tunnel", "066", 1), oak("rock-tunnel", "095", 1) ])
    end

    def self.lavender_town
      b = base("lavender-town")
      loc("lavender-town", "TOWN", "Lavender Town", 24, steps: 2,
        pins: { 1 => { tower: "lavender-town/exit-14-5" }, 2 => { west: "lavender-town/exit-west" } },
        trivia: trivia(b, anchor: "name-rater", tagged: true,
          pins: { house: "lavender-town/exit-7-13" },
          shot: scene_shot("lavender-name-rater", "NAME RATER"),
          warning: trivia_warning(b, "122", "MILES")),
        trainers: [
          rival(1625, mon("022", 25), mon("027", 20), mon("037", 23), mon("081", 22), mon("133", 25),
            where: scene_shot("pokemon-tower-rival", "WHERE"),
            battle: scene_shot("battle-pokemon-tower-rival", "BATTLE"))
        ])
    end

    def self.route_8
      loc("route-8", "ROUTE", "Route 8", 25, steps: 2,
        pins: { 1 => { gate: "route-8/exit-1-9" }, 2 => { path: "route-8/exit-13-3" } },
        encounters: [
          enc("route-8", "016", "GRASS", "40%", "20–22", "COMMON", "016", "017", "018"),
          enc("route-8", "063", "GRASS", "20%", "15–19", "UNCOMMON", "063", "064", "065"),
          enc("route-8", "019", "GRASS", "15%", "20", "UNCOMMON", "019", "020"),
          enc("route-8", "039", "GRASS", "10%", "19–24", "UNCOMMON", "039", "040"),
          enc("route-8", "017", "GRASS", "10%", "24", "UNCOMMON", "016", "017", "018"),
          enc("route-8", "064", "GRASS", "6%", "20–27", "RARE", "063", "064", "065")
        ])
    end

    # The second of Saffron's two tunnels, and the one the guide takes: Route 8 down, Route 7 up,
    # under the guards who want a drink. Nothing lives down here and nobody walks it, but two
    # hidden items sit on the floor and neither shows on-screen.
    def self.underground_path_west_east
      loc("underground-path-west-east", "TUNNEL", "Underground Path", 26, steps: [
          { pins: { in: "underground-path-west-east/exit-47-2" },
            hidden: [ "Elixir", "elixir", "underground-path-west-east-hidden-elixir",
                      "underground-path-west-east-elixir" ] },
          { pins: { out: "underground-path-west-east/exit-2-5" },
            hidden: [ "Nugget", "nugget", "underground-path-west-east-hidden-nugget",
                      "underground-path-west-east-nugget" ] }
        ])
    end

    def self.route_7
      loc("route-7", "ROUTE", "Route 7", 27, steps: 1,
        pins: { 1 => { west: "route-7/exit-west" } },
        encounters: [
          enc("route-7", "016", "GRASS", "40%", "20–22", "COMMON", "016", "017", "018"),
          enc("route-7", "063", "GRASS", "25%", "15–26", "UNCOMMON", "063", "064", "065"),
          enc("route-7", "019", "GRASS", "15%", "20", "UNCOMMON", "019", "020"),
          enc("route-7", "039", "GRASS", "10%", "19–24", "UNCOMMON", "039", "040"),
          enc("route-7", "017", "GRASS", "10%", "24", "UNCOMMON", "016", "017", "018")
        ])
    end

    def self.celadon_city
      loc("celadon-city", "CITY", "Celadon City", 28, steps: [
          { hidden: [ "PP Up", "pp-up", "celadon-city-hidden-pp-up", "celadon-city-pp-up" ] },
          { pins: { mansion: "celadon-city/exit-24-3" } },
          { items: [ [ "Coin Case", "coin_case" ] ], scene: "celadon-diner-coin-case",
            pins: { diner: "celadon-city/exit-31-27" } },
          { pins: { store: "celadon-city/exit-8-13" } },
          { items: [ [ "TM18 Counter", "tm18_counter" ] ], gift: [ "celadon-city", "tm18-counter" ],
            scene: "celadon-mart-3f-tm18" },
          {},
          {},
          { pins: { corner: "celadon-city/exit-28-19" } }
        ],
        encounters: [
          enc("celadon-city", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130"),
          enc("celadon-city", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("celadon-city", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119"),
          enc("celadon-city", "118", "SUPER ROD", "100%", "5–20", "COMMON", "118", "119"),
          enc("celadon-city", "133", "GIFT", "-", "25", "GIFT", "133", tip: true, from: true)
        ],
        trainers: [],
        oak_queue: [ oak("celadon-city", "133", 1) ])
    end

    # The walkthrough clears the Rocket Hideout before it takes the badge, so Celadon is walked
    # twice and the gym rides on the second visit, the way Vermilion's does after the S.S. Anne.
    def self.celadon_city_return
      b = base("celadon-city-return")
      Location.new(
        slug: "celadon-city-return", kind: "CITY", name: "Celadon City", order: 28,
        badge: "RAINBOW", note_key: "#{b}.note", intro_key: "#{b}.intro",
        steps: [
          step(b, 1, pins: { gym: "celadon-city/exit-12-27" }),
          step(b, 2)
        ], gym_after: 1,
        encounters: [], trainers: [], oak_queue: [],
        gym: gym("celadon-city", "Celadon Gym", "GRASS", "RAINBOW", "TM21 · MEGA DRAIN",
          leader("Erika", 3168, mon("114", 30), mon("070", 32), mon("044", 32),
            battle: scene_shot("battle-erika", "BATTLE"), opp: [ "ERIKA", 1 ]))
      )
    end

    # The two arrow-tile floors, named once so the step defs below can point at the legs of their
    # drawn routes without repeating the map name. Only a step whose walk actually rides an arrow
    # carries a `line:`, and so a map of its own: half of each floor's legs are plain corridor
    # walks (in at the door, round to the Rocket, out to the stairs), and a picture of a corridor
    # is a picture of nothing. `test_spinners.py` pins which legs those are.
    B2F = "rocket-hideout-b2f".freeze
    B3F = "rocket-hideout-b3f".freeze

    def self.rocket_hideout
      loc("rocket-hideout", "DUNGEON", "Game Corner / Rocket Hideout", 29,
        steps: [
          { pins: { guru: "rocket-hideout-game-corner/npc-guru-10",
                    man: "rocket-hideout-game-corner/npc-man-20",
                    fisher: "rocket-hideout-game-corner/npc-guru-20" } },
          { pins: { rocket: "rocket-hideout-game-corner/trainer-9-5",
                    poster: "rocket-hideout-game-corner/npc-poster",
                    stairs: "rocket-hideout-game-corner/exit-17-4" } },
          { hidden: [ "PP Up", "pp-up", "rocket-hideout-hidden-pp-up", "rocket-hideout-pp-up" ] },
          { item: [ "Escape Rope", "escape-rope" ], scene: "rocket-hideout-item-escape-rope",
            pins: { west: "rocket-hideout-b1f/trainer-12-6" } },
          { pins: { east: "rocket-hideout-b1f/trainer-26-8",
                    down: "rocket-hideout-b1f/exit-23-2" } },
          { pins: { rocket: "rocket-hideout-b2f/trainer-20-12",
                    down: "rocket-hideout-b2f/exit-21-8" } },
          { item: [ "TM Double Edge", "tm-double-edge" ], scene: "rocket-hideout-item-tm-double-edge",
            pins: { guard: "rocket-hideout-b3f/trainer-26-12" } },
          { hidden: [ "Nugget", "nugget", "rocket-hideout-hidden-nugget", "rocket-hideout-nugget" ] },
          {},
          { item: [ "Rare Candy", "rare-candy" ], scene: "rocket-hideout-item-rare-candy",
            line: [ B3F, 4 ] },
          { pins: { west: "rocket-hideout-b3f/trainer-10-22",
                    down: "rocket-hideout-b3f/exit-19-18" }, line: [ B3F, 5, 6 ] },
          { item: [ "HP Up", "hp-up" ], scene: "rocket-hideout-item-hp-up" },
          { item: [ "TM Razor Wind", "tm-razor-wind" ], scene: "rocket-hideout-item-tm-razor-wind" },
          { item: [ "Lift Key", "lift-key" ], scene: "rocket-hideout-item-lift-key",
            pins: { grunt: "rocket-hideout-b4f/trainer-11-2" } },
          { pins: { up: "rocket-hideout-b4f/exit-19-10", above: "rocket-hideout-b3f/exit-25-6" } },
          { item: [ "Moon Stone", "moon-stone" ], scene: "rocket-hideout-item-moon-stone",
            line: [ B2F, 3 ] },
          { item: [ "Nugget", "nugget" ], scene: "rocket-hideout-item-nugget" },
          { item: [ "TM Horn Drill", "tm-horn-drill" ], scene: "rocket-hideout-item-tm-horn-drill",
            line: [ B2F, 5 ] },
          { item: [ "Super Potion", "super-potion" ], scene: "rocket-hideout-item-super-potion",
            pins: { up: "rocket-hideout-b2f/exit-21-22" }, line: [ B2F, 6, 7 ] },
          { pins: { lower: "rocket-hideout-b1f/trainer-15-25" } },
          { item: [ "Hyper Potion", "hyper-potion" ], scene: "rocket-hideout-item-hyper-potion" },
          { pins: { upper: "rocket-hideout-b1f/trainer-18-17",
                    back: "rocket-hideout-b1f/exit-21-24" } },
          { pins: { lift: "rocket-hideout-b2f/exit-24-19" } },
          {},
          { item: [ "Iron", "iron" ], scene: "rocket-hideout-item-iron" },
          { pins: { giovanni: "rocket-hideout-b4f/trainer-25-3" } },
          { item: [ "Silph Scope", "silph-scope" ], scene: "rocket-hideout-item-silph-scope" },
          { hidden: [ "Super Potion", "super-potion", "rocket-hideout-hidden-super-potion", "rocket-hideout-super-potion" ] },
          { pins: { lift: "rocket-hideout-b1f/exit-24-19",
                    last: "rocket-hideout-b1f/trainer-28-18" } },
          { pins: { out: "rocket-hideout-game-corner/exit-15-17" } }
        ],
        encounters: [
          enc("rocket-hideout", "137", "GAME CORNER", "9999", "26", "GIFT", "137", tip: true),
          enc("rocket-hideout", "037", "GAME CORNER", "1000", "18", "GIFT", "037", "038", tip: true)
        ],
        oak_queue: [ oak("rocket-hideout", "137", 1) ],
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
      loc("power-plant", "BUILDING", "Power Plant", 45, steps: [
          { pins: { door: "power-plant/exit-4-35" } },
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
          { scene: "power-plant-zapdos" },
          {}
        ],
        encounters: [
          enc("power-plant", "081", "FLOORS", "40%", "30–35", "COMMON", "081", "082"),
          enc("power-plant", "082", "FLOORS", "20%", "33–38", "UNCOMMON", "081", "082"),
          enc("power-plant", "100", "FLOORS", "20%", "33–37", "UNCOMMON", "100", "101"),
          enc("power-plant", "088", "FLOORS", "15%", "33–37", "UNCOMMON", "088", "089"),
          enc("power-plant", "089", "FLOORS", "6%", "33–37", "RARE", "088", "089"),
          enc("power-plant", "145", "STATIC", "-", "50", "STATIC", "145", tip: true)
        ],
        oak_queue: [ oak("power-plant", "145", 1), oak("power-plant", "100", 1) ])
    end

    def self.route_21
      loc("route-21", "ROUTE", "Route 21", 48, steps: 2,
        encounters: [
          enc("route-21", "016", "GRASS", "55%", "11–17", "COMMON", "016", "017", "018"),
          enc("route-21", "019", "GRASS", "30%", "13–15", "COMMON", "019", "020"),
          enc("route-21", "017", "GRASS", "10%", "15–19", "UNCOMMON", "016", "017", "018"),
          enc("route-21", "020", "GRASS", "5%", "15", "RARE", "019", "020"),
          enc("route-21", "072", "SURF", "100%", "5–40", "COMMON", "072", "073"),
          enc("route-21", "129", "OLD ROD", "100%", "5", "COMMON", "129", "130", tip: true),
          enc("route-21", "060", "GOOD ROD", "50%", "10", "COMMON", "060", "061", "062"),
          enc("route-21", "118", "GOOD ROD", "50%", "10", "COMMON", "118", "119", tip: true),
          enc("route-21", "072", "SUPER ROD", "60%", "15–30", "COMMON", "072", "073"),
          enc("route-21", "120", "SUPER ROD", "30%", "20", "COMMON", "120", "121"),
          enc("route-21", "073", "SUPER ROD", "10%", "30", "UNCOMMON", "072", "073")
        ],
        oak_queue: [ oak("route-21", "129", 1), oak("route-21", "118", 1) ])
    end

    def self.step(base, n, items: [], hidden: [], shot: nil, html: false, link: nil, pins: {},
                  map: nil, dex_seen: nil, line: nil)
      Step.new(n: n, title_key: "#{base}.steps.#{n}.title",
        text_key: "#{base}.steps.#{n}.#{(html || pins.any?) ? 'text_html' : 'text'}",
        items: items, hidden: hidden, shot: shot, link: link, pins: pins, map: map, line: line,
        dex_seen: dex_seen && dex_seen(base, n, *dex_seen))
    end

    # The dex screen for a species a step shows you but does not let you catch. The numbers, the
    # species line and the entry text all come out of the game; only the "catch it later" line is
    # ours, so only that one is a locale key.
    def self.dex_seen(base, n, num)
      entry = dex_facts.fetch(num)
      DexSeen.new(num: num, name: entry.fetch("name"), species: entry.fetch("species"),
        types: entry.fetch("types"), height: entry.fetch("height"), weight: entry.fetch("weight"),
        text: entry.fetch("text"), art: "walkthrough/yellow/art/#{mon_key(num)}-sugimori.png",
        catch_key: "#{base}.steps.#{n}.catch_at")
    end

    def self.dex_facts
      @dex_facts ||= JSON.parse(File.read(File.join(__dir__, "yellow_dex.json"))).fetch("dex").freeze
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

    def self.mart_item(name, rec: false, rec_key: nil, desc_key: nil, tick: nil)
      facts = item_catalog.fetch(name)
      tm = facts["tm"]
      MartItem.new(name: name, sprite: (tm ? "tm-#{facts['type']}" : item_sprite(name)),
        price: facts["price"], desc_key: mart_desc_key(name, tm, desc_key),
        tm_no: tm, move: facts["move"], mtype: facts["type"],
        rec: (rec || !rec_key.nil?), rec_key: rec_key, tick: tick)
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
          gift: mart_item("TM18 Counter", desc_key: "#{b}.store.floors.3F.gift_desc",
            tick: gift_tick("celadon-city", "tm18-counter"))),
        dept_floor("4F", "shop", counters: [
          dept_counter("4F", "mart_gift_counter", celadon_stock("4F"), rec: [ "Poké Doll" ])
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
        roof: celadon_roof_trades,
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
      b = base("celadon-city")
      [ [ "Fresh Water", "TM13 Ice Beam" ], [ "Soda Pop", "TM48 Rock Slide" ],
        [ "Lemonade", "TM49 Tri Attack" ] ].map do |drink, tm|
        facts = item_catalog.fetch(tm)
        MartTrade.new(drink: drink, drink_sprite: item_sprite(drink),
          price: item_catalog.fetch(drink)["price"],
          tm_short: "TM#{format('%02d', facts['tm'])}", tm_sprite: "tm-#{facts['type']}",
          move: facts["move"], mtype: facts["type"],
          note_key: "#{b}.store.trades.#{item_key(tm)}")
      end
    end

    def self.prize_facts
      @prize_facts ||= JSON.parse(File.read(File.join(__dir__, "yellow_places.json")))
        .fetch("prizes").freeze
    end

    # The Game Corner's three counters, straight off the tables the prize menus read.
    def self.game_corner_prizes
      b = base("rocket-hideout")
      windows = prize_facts.fetch("windows").map do |window|
        PrizeWindow.new(id: window.fetch("window"),
          prizes: window.fetch("prizes").map { |facts| prize(b, facts) })
      end
      PrizeRoom.new(windows: windows, piles: prize_facts.fetch("coin_piles"))
    end

    def self.prize(base_key, facts)
      coins = facts.fetch("coins")
      if (dex = facts["dex"])
        entry = dex_facts.fetch(dex)
        Prize.new(name: entry.fetch("name"), sprite: "pokemon/yellow/#{dex}.png",
          level: facts.fetch("level"), mtype: nil, coins: coins,
          note_key: prize_note_key(base_key, entry.fetch("name")))
      else
        name = facts.fetch("item")
        item = item_catalog.fetch(name)
        Prize.new(name: name, sprite: "walkthrough/items/tm-#{item.fetch('type')}.png",
          level: nil, mtype: item.fetch("type"), coins: coins,
          note_key: prize_note_key(base_key, item.fetch("move")))
      end
    end

    # Only the prizes worth a paragraph carry one; the rest state their price and stop.
    PRIZE_NOTES = [ "Vulpix", "Porygon", "Hyper Beam" ].freeze

    def self.prize_note_key(base_key, name)
      return nil unless PRIZE_NOTES.include?(name)

      "#{base_key}.prizes.note_#{name.downcase.tr(' ', '_')}"
    end

    # Four drinks, because the girl takes three and a Saffron gate guard wants the fourth.
    def self.celadon_roof_trades
      buys = [ [ 2, "Fresh Water" ], [ 1, "Soda Pop" ], [ 1, "Lemonade" ] ].map do |qty, name|
        DrinkBuy.new(qty: qty, name: name, sprite: item_sprite(name),
          cost: qty * item_catalog.fetch(name)["price"])
      end
      RoofTrades.new(shot: scene_shot("celadon-roof-girl", "WHERE"), trades: celadon_trades,
        buys: buys, total: buys.sum(&:cost))
    end

    def self.item(base, n, name, key, at: nil, tick: nil)
      Item.new(name: name, where_key: "#{base}.steps.#{n}.items.#{key}",
        sprite: item_sprite(name), at: at, tick: tick)
    end

    # An NPC hands this one over, so no ball on the map holds it and there is no pin to tick
    # against. It takes an id built from the place that gives it instead, which the stop that
    # flags it as locked and the stop that walks back for it both name, so collecting it once
    # reads as collected on both pages.
    def self.gift_tick(slug, key) = "#{slug}/gift-#{key}"

    def self.hidden(base, n, name, key, scene, pin, at: nil)
      HiddenItem.new(name: name, where_key: "#{base}.steps.#{n}.hidden.#{key}",
        image: scenes.dig(scene, "image"), pin: pin, sprite: item_sprite(name), at: at)
    end

    def self.later(slug, key, name, kind, need, scene, pin = nil)
      base = base(slug)
      LaterItem.new(name: name, sprite: item_sprite(name), kind: kind, need: need,
        where_key: "#{base}.later.#{key}.where", after_key: "#{base}.later.#{key}.after",
        image: scenes.dig(scene, "image"), pin: pin, tick: gift_tick(slug, key))
    end

    TRIVIA_MARKS = { "yes" => "✓", "no" => "✕", "na" => "–" }.freeze

    def self.trivia(base, anchor:, cards: [], shot: nil, art: nil, note_icon: nil, tagged: false,
      warning: nil, pins: {})
      Trivia.new(anchor: anchor, title_key: "#{base}.trivia.title",
        intro_key: "#{base}.trivia.#{pins.any? ? 'intro_html' : 'intro'}",
        note_key: "#{base}.trivia.note", cards: cards, shot: shot, art: art, note_icon: note_icon,
        tag_key: (tagged ? "#{base}.trivia.tag" : nil), warning: warning, pins: pins)
    end

    # `name` is the nickname the cartridge ships, so it lives here rather than in the copy: MILES
    # is what the Route 2 scientist calls his Mr. Mime whichever language you read the guide in.
    def self.trivia_warning(base, dex, name)
      TriviaWarning.new(
        title_key: "#{base}.trivia.warning.title", body_key: "#{base}.trivia.warning.body",
        specimen: TriviaSpecimen.new(dex: dex, name: name,
          note_key: "#{base}.trivia.warning.specimen")
      )
    end

    # The grinding spot card: two species side by side with what each knockout pays, and the Repel
    # trick that leaves only the better one. `mons` are (dex, tone, sample level) triples; every
    # number on the card is worked out from the game's own base stats and the location's own
    # encounter rows, so nothing here can drift from what the cartridge does.
    GRIND_EXP_DIVISOR = 7
    GRIND_STEPS = 3

    def self.grind_spot(base, anchor:, after_map:, art:, note_icon:, encounters:, mons:)
      rows = mons.map { |dex, tone, level| grind_mon(base, encounters, dex, tone, level) }
      best = rows.map(&:exp).max
      GrindSpot.new(anchor: anchor, after_map: after_map, art: art, note_icon: note_icon,
        title_key: "#{base}.grind.title", intro_key: "#{base}.grind.intro",
        formula_key: "#{base}.grind.formula", warn_key: "#{base}.grind.warn",
        mons: rows.map { |mon| mon.with(fill: grind_fill(mon.exp, best)) },
        lead_level: rows.first.levels.split("–").last.to_i + 1,
        steps: (1..GRIND_STEPS).map do |n|
          GrindStep.new(n: n, title_key: "#{base}.grind.steps.#{n}.title",
            body_key: "#{base}.grind.steps.#{n}.body_html")
        end)
    end

    # The bar under each figure, as a percentage of the best on offer, in fives. A width has to be
    # a class rather than an inline style (the CSP blocks those), so it lands on one of twenty-one
    # steps; a bar comparing two numbers reads the same at that granularity.
    GRIND_FILL_STEP = 5

    def self.grind_fill(exp, best)
      (exp * 100.0 / best / GRIND_FILL_STEP).round * GRIND_FILL_STEP
    end

    def self.grind_mon(base, encounters, dex, tone, level)
      row = encounters.find { |e| e.dex == dex }
      entry = dex_facts.fetch(dex)
      GrindMon.new(dex: dex, name: row.name, tone: tone, rarity: row.rarity, share: row.rate,
        levels: row.level, level: level, fill: 0,
        exp: entry.fetch("base_exp") * level / GRIND_EXP_DIVISOR,
        type: entry.fetch("types").first, hp: entry.fetch("hp"), speed: entry.fetch("speed"),
        tips_key: "#{base}.grind.tips.#{mon_key(dex)}")
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
