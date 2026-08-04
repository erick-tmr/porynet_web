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
      build_entry(game, dex, home, here, here || span.find { |loc| loc.dex_list.include?(dex) })
    end

    def self.build_entry(game, dex, home, here, shown)
      qty = bodies_for(game, dex)
      best = game.best_catches[dex]
      why = why_for(shown, dex, qty, best)
      found = encounter_at(shown, dex)
      PlanEntry.new(dex: dex, name: Yellow::NAMES.fetch(dex), at: shown.slug,
        stop_name: shown.name, qty: qty, chain: Evolutions.chain_for(dex), fresh: !here.nil?,
        done_at: here ? nil : home.name, how: found.how, rate: found.rate, best: best,
        why_key: why.first, why_args: why.last)
    end

    # A stop's hand-written Oak line wins whenever it cannot contradict the quota, which is to say
    # whenever one body is all the species owes. Past that the count is the point, so the template
    # states it rather than letting "log one" sit under a x2 badge.
    def self.why_for(loc, dex, qty, best)
      name = Yellow::NAMES.fetch(dex)
      return [ "walkthrough.ui.ld_why_stages", { count: qty, name: name } ] if qty > 1

      override = loc.oak_queue.find { |owed| owed.dex == dex }
      return [ override.why_key, {} ] if override
      return [ "walkthrough.ui.ld_why_sole", { name: name } ] if best&.only

      [ "walkthrough.ui.ld_why_best", { name: name, stop: loc.name } ]
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

    # One card per species would say the same sentence four times on a page whose stops share their
    # grass, so the species that repeat are named together in a single note.
    def self.shared_notes(leg, entries)
      roll_up(:shared, entries.select { |entry| stops_holding(leg, entry.dex) > 1 })
    end

    def self.gift_notes(game, entries)
      roll_up(:one_copy, entries.select { |entry| entry.queued? && !repeatable?(game, entry.dex) })
    end

    def self.roll_up(kind, entries)
      return [] if entries.empty?

      [ ChallengeNote.new(kind: kind,
        args: { names: entries.map(&:name).to_sentence, count: entries.size }) ]
    end

    def self.crowd_notes(entries)
      bodies = entries.select(&:queued?).sum(&:qty)
      return [] if bodies < CROWDED_PAGE

      [ ChallengeNote.new(kind: :box_space, args: { count: bodies }) ]
    end

    def self.families_for(game, entries)
      entries.select(&:queued?).uniq { |entry| entry.chain.first }
        .map { |entry| family_for(game, entry) }
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

    # Catching and evolving are not two lists of species but one list split by how you would
    # actually get each one here, so a 1% Venomoth sits under BY EVOLVING next to the Venonat it
    # grows from rather than under CATCH HERE promising odds nobody should take.
    def self.groups_for(game, leg, entries, due)
      reached = reached_upto(game, leg_order(leg).last.slug).map(&:slug)
      caught, grown = owed_here(game, leg, entries, due)
        .partition { |dex| catchable_stop(game, dex, reached) }
      [ OakGroup.new(kind: :catch, note_key: "walkthrough.ui.oak_group_catch_note",
          tiles: caught.map { |dex| tile_for(game, dex, reached) }),
        OakGroup.new(kind: :evolve, note_key: "walkthrough.ui.oak_group_evolve_note",
          tiles: grown.map { |dex| tile_for(game, dex, reached) }) ]
    end

    def self.owed_here(game, leg, entries, due)
      fresh = entries.select(&:fresh?).map(&:dex)
      fresh + ((due - registerable_before(game, leg_order(leg).first.slug)) - fresh)
    end

    def self.catch_tile(entry)
      rated = Yellow.parse_rate(entry.rate)
      OakTile.new(dex: entry.dex, name: entry.name,
        via_key: rated ? "walkthrough.ui.via_catch" : "walkthrough.ui.via_gift",
        via_args: rated ? { how: entry.how, rate: entry.rate } : { how: entry.how },
        where_key: "walkthrough.ui.where_stop", where_args: { stop: entry.stop_name })
    end

    # A species can be both catchable and evolvable, and the honest answer depends on where you
    # stand. Fearow is a 25% spawn on Route 17, but in Brock's window the only Fearow you can have
    # is a Spearow that hit level 20, and a Pidgeotto you could technically hunt at 1% is still
    # better evolved. So a tile names a catch only at a stop you have already walked and at odds
    # worth walking for, and names the evolution otherwise.
    def self.tile_for(game, dex, reached)
      stop = catchable_stop(game, dex, reached)
      return catch_tile(entry_for(game, [ stop ], dex)) if stop

      step = Evolutions.into(dex).first
      OakTile.new(dex: dex, name: Yellow::NAMES.fetch(dex), via_key: step_key(step),
        via_args: step_args(step), where_key: "walkthrough.ui.where_evolve",
        where_args: { name: Yellow::NAMES.fetch(step.from) })
    end

    def self.catchable_stop(game, dex, reached)
      best = stops_with(game, dex).select { |loc| reached.include?(loc.slug) }
        .max_by { |loc| stop_rate(loc, dex) || 100 }
      return nil if best.nil?

      rate = stop_rate(best, dex)
      best if rate.nil? || rate >= WORTH_CATCHING_RATE || Evolutions.into(dex).empty?
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
      reached = reached_upto(game, leg_order(leg).last.slug).map(&:slug)
      earlier_dex(game, leg).map { |dex| tile_for(game, dex, reached) }
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
