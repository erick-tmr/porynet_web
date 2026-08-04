module Walkthrough
  module Challenge
    WORTH_CATCHING_RATE = 5
    CROWDED_PAGE = 6

    def self.play_order(legs) = legs.flat_map { |leg| leg_order(leg) }

    def self.leg_order(leg)
      finale = leg.finale
      finale ? (leg.locations - [ finale ]) + [ finale ] : leg.locations
    end

    def self.windows(legs)
      play_order(legs).slice_after(&:badge?).each_with_index.map do |group, index|
        closer = group.last
        Window.new(number: index + 1, badge: closer.badge, gym: closer.gym,
          slugs: group.map(&:slug))
      end
    end

    def self.reached_upto(game, slug)
      order = play_order(game.legs)
      order.first(order.index { |loc| loc.slug == slug } + 1)
    end

    def self.registerable(game, slug)
      seen = reached_upto(game, slug)
      grow(seen.flat_map(&:dex_list).uniq, seen.map(&:slug))
    end

    def self.grow(roster, reached)
      grown = roster.dup
      index = 0
      while index < grown.size
        Evolutions.out_of(grown[index]).each do |evo|
          grown << evo.to if performable?(evo, reached) && !grown.include?(evo.to)
        end
        index += 1
      end
      grown
    end

    def self.performable?(evo, reached)
      return false if evo.trade? || Evolutions.refused?(evo.to)

      evo.level? || reached.include?(Evolutions.stone_source(evo.arg))
    end

    def self.evolvable?(dex)
      Evolutions.into(dex).any? { |evo| performable?(evo, Evolutions::STONE_SOURCES.values) }
    end

    def self.ancestors_of(dex)
      line = []
      stage = dex
      while (step = Evolutions.into(stage).first)
        line.unshift(step.from)
        stage = step.from
      end
      line
    end

    def self.wild_encounters(game, dex)
      game.locations.flat_map(&:encounters).select { |enc| enc.dex == dex && enc.wild? }
    end

    def self.top_rate(game, dex)
      wild_encounters(game, dex).filter_map { |enc| Yellow.parse_rate(enc.rate) }.max
    end

    def self.repeatable?(game, dex) = wild_encounters(game, dex).any?

    def self.worth_catching?(game, dex)
      rate = top_rate(game, dex)
      !rate.nil? && rate >= WORTH_CATCHING_RATE
    end

    def self.self_sourced?(game, dex)
      return true unless evolvable?(dex)

      worth_catching?(game, dex)
    end

    def self.body_source(game, dex)
      ancestors_of(dex).select { |stage| worth_catching?(game, stage) && repeatable?(game, stage) }
        .max_by { |stage| top_rate(game, stage) }
    end

    def self.dependents(game, dex)
      Evolutions.chain_for(dex).select do |stage|
        !self_sourced?(game, stage) && body_source(game, stage) == dex
      end
    end

    def self.bodies_for(game, dex)
      return 1 unless repeatable?(game, dex)

      (self_sourced?(game, dex) ? 1 : 0) + dependents(game, dex).size
    end

    def self.stops_with(game, dex)
      game.locations.select { |loc| loc.dex_list.include?(dex) }
    end

    def self.home_stop(game, dex)
      order = play_order(game.legs)
      stops = stops_with(game, dex)
      stops.max_by { |loc| [ stop_rate(loc, dex) || 0, -order.index(loc) ] }
    end

    def self.stop_rate(loc, dex)
      loc.encounters.select { |enc| enc.dex == dex }.filter_map { |enc| Yellow.parse_rate(enc.rate) }.max
    end

    def self.encounter_at(loc, dex) = loc.encounters.find { |enc| enc.dex == dex }

    def self.plan(game, leg)
      span = leg_order(leg)
      entries = leg.locations.flat_map(&:dex_list).uniq.map { |dex| entry_for(game, span, dex) }
      due = registerable(game, span.last.slug)
      PagePlan.new(window: window_for(game, leg), entries: entries, due: due,
        notes: notes_for(game, leg, entries), families: families_for(game, entries),
        groups: groups_for(game, leg, entries, due), earlier: earlier_for(game, leg),
        locked: locked_for(game, due))
    end

    def self.window_for(game, leg) = game.windows.find { |win| win.covers?(leg_order(leg).last.slug) }

    def self.entry_for(game, span, dex)
      home = home_stop(game, dex)
      here = span.find { |loc| loc.slug == home.slug }
      shown = here || span.find { |loc| loc.dex_list.include?(dex) }
      PlanEntry.new(dex: dex, name: Yellow::NAMES.fetch(dex), at: shown.slug,
        stop_name: shown.name, qty: bodies_for(game, dex), chain: Evolutions.chain_for(dex),
        fresh: !here.nil?, done_at: here ? nil : home.name, how: encounter_at(shown, dex).how,
        rate: encounter_at(shown, dex).rate, best: game.best_catches[dex])
    end

    def self.boxed_before?(game, span, dex)
      order = play_order(game.legs)
      order.index(home_stop(game, dex)) < order.index(span.first)
    end

    def self.notes_for(game, leg, entries)
      later_notes(game, leg, entries) + shared_notes(leg, entries) +
        gift_notes(game, entries) + crowd_notes(entries)
    end

    def self.later_notes(game, leg, entries)
      span = leg_order(leg)
      entries.reject { |entry| entry.fresh? || boxed_before?(game, span, entry.dex) }
        .map { |entry| ChallengeNote.new(kind: :later, args: { name: entry.name, stop: entry.done_at }) }
    end

    def self.stops_holding(leg, dex) = leg.locations.count { |loc| loc.dex_list.include?(dex) }

    def self.shared_notes(leg, entries)
      entries.select { |entry| stops_holding(leg, entry.dex) > 1 }
        .map { |entry| ChallengeNote.new(kind: :shared, args: { name: entry.name, stop: entry.stop_name }) }
    end

    def self.gift_notes(game, entries)
      entries.select { |entry| entry.queued? && !repeatable?(game, entry.dex) }
        .map { |entry| ChallengeNote.new(kind: :one_copy, args: { name: entry.name }) }
    end

    def self.crowd_notes(entries)
      bodies = entries.select(&:queued?).sum(&:qty)
      return [] if bodies < CROWDED_PAGE

      [ ChallengeNote.new(kind: :box_space, args: { count: bodies }) ]
    end

    def self.families_for(game, entries)
      entries.select(&:queued?).map { |entry| family_for(game, entry) }
    end

    def self.family_for(game, entry)
      Family.new(name: Yellow::NAMES.fetch(entry.chain.first),
        stages: entry.chain.map { |dex| stage_for(game, dex) })
    end

    def self.stage_for(game, dex)
      step = Evolutions.into(dex).first
      FamilyStage.new(dex: dex, name: Yellow::NAMES.fetch(dex), step_key: step_key(step),
        step_args: step_args(step), owed: !self_sourced?(game, dex) && body_source(game, dex).nil?)
    end

    def self.step_key(step)
      return "walkthrough.ui.step_catch" if step.nil?
      return "walkthrough.ui.step_level" if step.level?

      step.stone? ? "walkthrough.ui.step_stone" : "walkthrough.ui.step_trade"
    end

    def self.step_args(step) = step&.level? ? { level: step.arg } : { stone: step&.arg }

    def self.groups_for(game, leg, entries, due)
      [ OakGroup.new(kind: :catch, note_key: "walkthrough.ui.oak_group_catch_note",
          tiles: entries.select(&:fresh?).map { |entry| catch_tile(entry) }),
        OakGroup.new(kind: :evolve, note_key: "walkthrough.ui.oak_group_evolve_note",
          tiles: evolve_tiles(game, leg, entries, due)) ]
    end

    def self.catch_tile(entry)
      OakTile.new(dex: entry.dex, name: entry.name, via_key: "walkthrough.ui.via_catch",
        via_args: { how: entry.how, rate: entry.rate },
        where_key: "walkthrough.ui.where_stop", where_args: { stop: entry.stop_name })
    end

    def self.evolve_tiles(game, leg, entries, due)
      ((due - registerable_before(game, leg_order(leg).first.slug)) - entries.map(&:dex))
        .map { |dex| tile_for(game, dex) }
    end

    def self.tile_for(game, dex)
      home = home_stop(game, dex)
      return catch_tile(entry_for(game, [ home ], dex)) if home

      step = Evolutions.into(dex).first
      OakTile.new(dex: dex, name: Yellow::NAMES.fetch(dex), via_key: step_key(step),
        via_args: step_args(step), where_key: "walkthrough.ui.where_evolve",
        where_args: { name: Yellow::NAMES.fetch(step.from) })
    end

    def self.registerable_before(game, slug)
      order = play_order(game.legs)
      opened = order.index { |loc| loc.slug == slug }
      opened.zero? ? [] : registerable(game, order[opened - 1].slug)
    end

    def self.window_span(game, leg)
      order = play_order(game.legs).map(&:slug)
      opens = order.index(leg_order(leg).first.slug)
      window_for(game, leg).slugs.select { |slug| order.index(slug) < opens }
    end

    def self.earlier_dex(game, leg)
      slugs = window_span(game, leg)
      return [] if slugs.empty?

      registerable(game, slugs.last) - registerable_before(game, window_for(game, leg).slugs.first)
    end

    def self.earlier_for(game, leg)
      earlier_dex(game, leg).map { |dex| tile_for(game, dex) }
    end

    def self.locked_for(game, due)
      candidates = due.flat_map { |dex| Evolutions.out_of(dex) }.map(&:to).uniq - due
      candidates.map { |dex| locked_entry(game, dex) }
    end

    def self.locked_entry(game, dex)
      step = Evolutions.into(dex).find { |evo| !evo.trade? } || Evolutions.into(dex).first
      LockedEntry.new(dex: dex, name: Yellow::NAMES.fetch(dex), gate_key: gate_key(dex, step),
        gate_args: step_args(step), where_key: locked_where_key(dex, step),
        where_args: { stone: step.arg, name: Yellow::NAMES.fetch(step.from),
                      stop: home_stop(game, dex)&.name })
    end

    def self.gate_key(dex, step)
      return "walkthrough.ui.gate_refused" if Evolutions.refused?(dex)

      step.trade? ? "walkthrough.ui.step_trade" : step_key(step)
    end

    def self.locked_where_key(dex, step)
      return "walkthrough.ui.locked_wild" if Evolutions.refused?(dex)

      step.trade? ? "walkthrough.ui.locked_trade" : "walkthrough.ui.locked_stone"
    end
  end
end
