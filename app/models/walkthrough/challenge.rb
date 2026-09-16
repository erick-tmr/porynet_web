module Walkthrough
  module Challenge
    WORTH_CATCHING_RATE = 4
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
      badges = badges_before(seen)
      grow(game.evolutions, seen.flat_map { |loc| loc.dex_list_after(badges) }.uniq, seen.map(&:slug))
    end

    def self.badges_before(seen) = seen[0...-1].filter_map(&:badge)

    def self.grow(table, roster, reached)
      grown = roster.dup
      index = 0
      while index < grown.size
        table.out_of(grown[index]).each do |evo|
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

    def self.evolvable?(table, dex)
      table.into(dex).any? { |evo| performable?(evo, Evolutions::STONE_SOURCES.values) }
    end

    def self.fillable?(table, dex)
      table.into(dex).any? do |evo|
        !Evolutions.refused?(evo.to) &&
          (evo.trade? || performable?(evo, Evolutions::STONE_SOURCES.values))
      end
    end

    def self.ancestors_of(table, dex)
      line = []
      stage = dex
      while (step = table.into(stage).first)
        line.unshift(step.from)
        stage = step.from
      end
      line
    end

    def self.wild_encounters(game, dex)
      game.locations.flat_map(&:encounters).select { |enc| enc.dex == dex && enc.wild? }
    end

    def self.top_rate(game, dex)
      stops_with(game, dex).filter_map { |loc| stop_rate(loc, dex) }.max
    end

    def self.repeatable?(game, dex) = wild_encounters(game, dex).any?

    def self.purchasable?(game, dex)
      game.locations.flat_map(&:encounters).any? { |enc| enc.dex == dex && enc.purchased? }
    end

    def self.standing?(game, dex)
      game.locations.flat_map(&:encounters).any? { |enc| enc.dex == dex && enc.static? }
    end

    def self.worth_catching?(game, dex)
      return true if purchasable?(game, dex) || standing?(game, dex)

      rate = top_rate(game, dex)
      !rate.nil? && rate >= WORTH_CATCHING_RATE
    end

    def self.rungs(table, dex) = [ dex ] + ancestors_of(table, dex).reverse

    def self.body_source(game, dex)
      return dex unless fillable?(game.evolutions, dex)

      rungs(game.evolutions, dex).find { |stage| worth_catching?(game, stage) } ||
        best_odds(game, ancestors_of(game.evolutions, dex))
    end

    def self.best_odds(game, stages)
      stages.select { |stage| top_rate(game, stage) }.max_by { |stage| top_rate(game, stage) }
    end

    def self.self_sourced?(game, dex) = body_source(game, dex) == dex

    def self.covered_by(game, dex)
      game.evolutions.chain_for(dex).select { |stage| body_source(game, stage) == dex }
    end

    def self.bodies_for(game, dex) = covered_by(game, dex).size

    def self.stops_with(game, dex)
      game.locations.select { |loc| loc.dex_list.include?(dex) }
    end

    def self.home_stop(game, dex)
      order = play_order(game.legs)
      stops = stops_with(game, dex)
      stops.max_by { |loc| [ stop_rate(loc, dex) || 0, -order.index(loc) ] }
    end

    def self.stop_rate(loc, dex)
      loc.encounters.select { |enc| enc.dex == dex && enc.unlocked_from <= loc.order }
        .filter_map { |enc| Gen1Guide.parse_rate(enc.rate) }.max
    end

    def self.encounter_at(loc, dex) = loc.encounters.find { |enc| enc.dex == dex }

    def self.plan(game, leg)
      span = leg_order(leg)
      entries = leg.locations.flat_map(&:dex_list).uniq.map { |dex| entry_for(game, span, dex) }
      due = registerable(game, span.last.slug)
      PagePlan.new(window: window_for(game, leg), entries: entries, due: due,
        notes: notes_for(game, leg, entries), families: families_for(game, entries),
        groups: groups_for(game, leg, due), earlier: earlier_for(game, leg),
        locked: locked_for(game, due))
    end

    def self.window_for(game, leg) = game.windows.find { |win| win.covers?(leg_order(leg).last.slug) }

    def self.entry_for(game, span, dex)
      home = home_stop(game, dex)
      here = span.find { |loc| loc.slug == home.slug }
      build_entry(game, span, dex, home, here || span.find { |loc| loc.dex_list.include?(dex) })
    end

    def self.build_entry(game, span, dex, home, shown)
      covers = covered_by(game, dex)
      here = home.slug == shown.slug
      later = covers.any? ? later_for(game, dex) : nil
      best = game.best_catches[dex]
      PlanEntry.new(dex: dex, name: Gen1Guide::NAMES.fetch(dex), at: shown.slug,
        stop_name: shown.name, covers: covers, chain: game.evolutions.chain_for(dex), fresh: here,
        boxed: !here && boxed_before?(game, span, dex),
        done_at: (best&.place || home.name unless here), done_how: (best&.how unless here),
        later: later, **catch_facts(shown, dex, covers, later, best))
    end

    def self.catch_facts(shown, dex, covers, later, best)
      found = encounter_at(shown, dex)
      why = why_for(shown, found, covers.size, best, later)
      { qty: covers.size, how: found.how, rate: found.rate, best: best,
        why_key: why.first, why_args: why.last }
    end

    def self.later_for(game, dex)
      steps = game.evolutions.out_of(dex)
      step = steps.find { |evo| body_source(game, evo.to) == dex } || steps.first
      step && later_stage(game, dex, step)
    end

    def self.later_stage(game, dex, step)
      kind, extra = later_kind(game, dex, step)
      return nil if kind.nil?

      LaterStage.new(dex: step.to, name: Gen1Guide::NAMES.fetch(step.to), kind: kind,
        args: { name: Gen1Guide::NAMES.fetch(step.to), base: Gen1Guide::NAMES.fetch(dex) }.merge(extra))
    end

    def self.later_kind(game, dex, step)
      later = step.to
      return [ :refused, {} ] if Evolutions.refused?(later)
      return [ :trade, {} ] if unreachable?(game, later)
      return caught_kind(game, later) if self_sourced?(game, later)
      return grown_kind(game, later, step) if body_source(game, later) == dex

      nil
    end

    def self.caught_kind(game, dex)
      return [ :catch, spawn_args(game, dex) ] if top_rate(game, dex)

      [ :static, { stop: home_stop(game, dex).name } ]
    end

    def self.grown_kind(game, later, step)
      return [ :rare, spawn_args(game, later) ] if top_rate(game, later)
      return [ :level, { level: step.arg } ] if step.level?

      [ :stone, { stone: step.arg } ]
    end

    def self.spawn_args(game, dex)
      stop = home_stop(game, dex)
      { stop: stop.name, rate: best_encounter_at(stop, dex).rate }
    end

    def self.best_encounter_at(loc, dex)
      loc.encounters.select { |enc| enc.dex == dex }.max_by { |enc| Gen1Guide.parse_rate(enc.rate) || 0 }
    end

    def self.why_for(loc, found, qty, best, later)
      given = { name: found.name, stop: loc.name }
      return [ "walkthrough.ui.ld_why_gift", given ] if found.gift?

      wild_why(loc, found, qty, best, later, given)
    end

    def self.wild_why(loc, found, qty, best, later, given)
      return [ "walkthrough.ui.ld_why_stages", { count: qty, name: found.name } ] if qty > 1

      override = loc.oak_queue.find { |owed| owed.dex == found.dex }
      return [ override.why_key, {} ] if override
      return [ "walkthrough.ui.ld_why_sole", { name: found.name } ] if best&.only
      return [ "walkthrough.ui.ld_why_later", later.args ] if later&.catch?

      [ "walkthrough.ui.ld_why_best", given ]
    end

    def self.boxed_before?(game, span, dex)
      order = play_order(game.legs)
      order.index(home_stop(game, dex)) < order.index(span.first)
    end

    def self.notes_for(game, leg, entries)
      later_notes(entries) + shared_notes(leg, entries) +
        gift_notes(game, entries) + crowd_notes(entries)
    end

    def self.later_notes(entries)
      entries.reject { |entry| entry.fresh? || entry.boxed? }
        .map { |entry| ChallengeNote.new(kind: :later, args: { name: entry.name, stop: entry.done_at }) }
    end

    def self.stops_holding(leg, dex) = leg.locations.count { |loc| loc.dex_list.include?(dex) }

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
      Family.new(name: Gen1Guide::NAMES.fetch(entry.chain.first),
        stages: entry.chain.map { |dex| stage_for(game, dex) })
    end

    def self.unreachable?(game, dex) = stops_with(game, dex).empty? && !evolvable?(game.evolutions, dex)

    def self.stage_for(game, dex)
      step = game.evolutions.into(dex).first
      traded = unreachable?(game, dex)
      FamilyStage.new(dex: dex, name: Gen1Guide::NAMES.fetch(dex),
        step_key: traded ? "walkthrough.ui.step_trade" : step_key(step),
        step_args: traded ? {} : step_args(step),
        owed: traded || body_source(game, dex).nil?)
    end

    def self.step_key(step)
      return "walkthrough.ui.step_catch" if step.nil?

      step.level? ? "walkthrough.ui.step_level" : "walkthrough.ui.step_stone"
    end

    def self.step_args(step) = step&.level? ? { level: step.arg } : { stone: step&.arg }

    def self.groups_for(game, leg, due)
      reached = reached_upto(game, leg_order(leg).last.slug).map(&:slug)
      here = leg_order(leg).map(&:slug)
      caught, grown = owed_here(game, leg, due)
        .partition { |dex| catchable_stop(game, dex, reached) }
      choice, grown = grown.partition { |dex| one_specimen_line?(game, dex, grown) }
      [ oak_group(:catch, game, caught, reached, here),
        oak_group(:evolve, game, grown, reached, here),
        oak_group(:choice, game, choice, reached, here, pick: 1) ]
    end

    def self.oak_group(kind, game, dexes, reached, here, pick: nil)
      OakGroup.new(kind: kind, pick: pick,
        note_key: "walkthrough.ui.oak_group_#{kind}_note",
        tiles: dexes.map { |dex| tile_for(game, dex, reached, here) })
    end

    def self.one_specimen_line?(game, dex, grown)
      base = game.evolutions.into(dex).first&.from
      return false if base.nil? || game.best_catches[base]

      grown.count { |other| game.evolutions.into(other).first&.from == base } > 1
    end

    def self.owed_here(game, leg, due)
      (due - registerable_before(game, leg_order(leg).first.slug)).sort
    end

    def self.catch_tile(entry, away = nil)
      return OakTile.new(dex: entry.dex, name: entry.name, via_key: "walkthrough.ui.via_away",
        via_args: { how: entry.how, stop: away }) if away

      rated = Gen1Guide.parse_rate(entry.rate)
      OakTile.new(dex: entry.dex, name: entry.name,
        via_key: rated ? "walkthrough.ui.via_catch" : "walkthrough.ui.via_gift",
        via_args: rated ? { how: entry.how, rate: entry.rate } : { how: entry.how })
    end

    def self.tile_for(game, dex, reached, here = reached)
      stop = catchable_stop(game, dex, reached)
      return catch_tile(entry_for(game, [ stop ], dex), off_page(stop, here)) if stop

      step = game.evolutions.into(dex).first
      OakTile.new(dex: dex, name: Gen1Guide::NAMES.fetch(dex), via_key: step_key(step),
        via_args: step_args(step))
    end

    def self.off_page(stop, here)
      stop.name unless here.include?(stop.slug)
    end

    def self.catchable_stop(game, dex, reached)
      best = stops_with(game, dex).select { |loc| reached.include?(loc.slug) }
        .max_by { |loc| stop_rate(loc, dex) || 100 }
      return nil if best.nil?

      rate = stop_rate(best, dex)
      best if rate.nil? || rate >= WORTH_CATCHING_RATE || game.evolutions.into(dex).empty?
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

      (registerable(game, slugs.last) - registerable_before(game, window_for(game, leg).slugs.first)).sort
    end

    def self.earlier_for(game, leg)
      reached = reached_upto(game, leg_order(leg).last.slug).map(&:slug)
      earlier_dex(game, leg).map { |dex| tile_for(game, dex, reached) }
    end

    def self.locked_for(game, due)
      candidates = (due.flat_map { |dex| game.evolutions.out_of(dex) }.map(&:to).uniq - due).sort
      candidates.map { |dex| locked_entry(game, dex) }
    end

    def self.locked_entry(game, dex)
      table = game.evolutions
      step = table.into(dex).find { |evo| !evo.trade? } || table.into(dex).first
      LockedEntry.new(dex: dex, name: Gen1Guide::NAMES.fetch(dex), gate_key: gate_key(dex, step),
        gate_args: step_args(step), where_key: locked_where_key(dex, step),
        where_args: { stone: step.arg, name: Gen1Guide::NAMES.fetch(step.from) })
    end

    def self.gate_key(dex, step)
      return "walkthrough.ui.gate_refused" if Evolutions.refused?(dex)

      step.trade? ? "walkthrough.ui.step_trade" : step_key(step)
    end

    def self.locked_where_key(dex, step)
      return "walkthrough.ui.locked_refused" if Evolutions.refused?(dex)

      step.trade? ? "walkthrough.ui.locked_trade" : "walkthrough.ui.locked_stone"
    end
  end
end
