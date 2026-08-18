module ApplicationHelper
  def accent_last(text)
    words = text.to_s.split(" ")
    return safe_join([ text ]) if words.size < 2

    head = words[0..-2].join(" ")
    safe_join([ head, " ", content_tag(:span, words.last, class: "pn-accent") ])
  end

  def leg_title(leg)
    leg.single? ? leg.from : "#{leg.from} → #{leg.to}"
  end

  def r2_asset_url(path)
    "#{Rails.application.config.x.r2_public_host}/#{path}"
  end

  def r2_image_tag(path, **options)
    image_tag(r2_asset_url(path), **options)
  end

  # A mart item's blurb: its own localized description, or for a plain sold TM the type of move
  # it teaches (the game gives Gen 1 TMs no description of their own).
  def mart_item_desc(item)
    return t(item.desc_key) if item.desc?

    t("walkthrough.ui.tm_type_desc", type: t("walkthrough.ui.types.#{item.mtype}"))
  end

  def poke_dollar(amount)
    tag.span(class: "pn-money-value") do
      safe_join([
        tag.span(nil, class: "pn-money", role: "img", "aria-label": t("walkthrough.ui.poke_dollar")),
        tag.span(number_with_delimiter(amount), class: "pn-money-value__n")
      ])
    end
  end

  def step_text(step)
    marks = step.marks.transform_values { |key| map_mark(key) }
    return t(step.text_key, **marks) unless step.link?

    t(step.text_key, **marks,
      href: walkthrough_leg_path(game: @game.slug, leg: step.link.leg, anchor: step.link.anchor))
  end

  # The letter a step's prose points at, wearing the chip the map pin and legend row give it.
  def map_mark(key)
    tag.span(key, class: "pn-wt-mark", title: t("walkthrough.ui.map_marker_hint"))
  end

  def walkthrough_page_controller(game)
    tag.attributes(data: { controller: "progress-toggle mode-toggle",
                           progress_toggle_game_value: game.slug,
                           mode_toggle_game_value: game.slug })
  end

  # Attributes that make an element a tick target for progress_toggle_controller. Ids are built
  # from where a thing sits in the walkthrough, so they survive copy edits to its description.
  def tickable(kind, id)
    { role: "button", tabindex: 0, "aria-pressed": "false",
      data: { progress_toggle_target: "item", kind: kind, progress_id: id,
              action: "click->progress-toggle#toggle " \
                      "keydown.enter->progress-toggle#toggle " \
                      "keydown.space->progress-toggle#toggle" } }
  end

  # Every caption renders up front and CSS picks one, so no user-visible string lives in JS and
  # the toast cannot get stuck showing the wrong state. The done/todo pair is personalized with
  # the subject name; the error caption and RETRY only surface when a localStorage save fails.
  def progress_toast(flavor, name:)
    tag.span(class: "pn-wt-toast", aria: { live: "polite" },
             data: { action: "click->progress-toggle#stop" }) do
      safe_join([
        tag.span(t("walkthrough.ui.toast_#{flavor}_on", name: name), class: "pn-wt-toast__msg pn-wt-toast__msg--done"),
        tag.span(t("walkthrough.ui.toast_#{flavor}_off", name: name), class: "pn-wt-toast__msg pn-wt-toast__msg--todo"),
        tag.span(t("walkthrough.ui.toast_error"), class: "pn-wt-toast__msg pn-wt-toast__msg--error"),
        tag.button(t("walkthrough.ui.toast_retry"), type: "button", class: "pn-wt-toast__retry",
                   data: { action: "click->progress-toggle#retry" })
      ])
    end
  end

  def progress_slot(role, ids, **options)
    options.deep_merge(data: { progress_toggle_target: role, kind: "caught",
                               progress_ids: ids.join(" ") })
  end

  def progress_count(ids) = tag.span(0, **progress_slot("count", ids))

  def progress_remaining(ids) = tag.span(ids.size, **progress_slot("remaining", ids))

  def progress_meter(ids)
    tag.div(**progress_slot("meter", ids, class: "pn-wt-meter")) do
      tag.div(nil, class: "pn-wt-meter__fill")
    end
  end

  def meter_percent = tag.span("0%", data: { meter_pct: true })

  def body_count_slot = tag.span(0, data: { body_counter_target: "have" })

  def body_want_slot(quota) = tag.span(quota, data: { body_counter_target: "want" })

  def body_progress(quota)
    t("walkthrough.ui.ld_caught_progress_html", want: body_want_slot(quota), have: body_count_slot)
  end

  def body_pill(quota)
    t("walkthrough.ui.pill_box_html", want: body_want_slot(quota), have: body_count_slot)
  end

  def body_quota(quota) = t("walkthrough.ui.ld_qty_html", count: body_want_slot(quota))

  def ld_stat_entries(queue) = queue.map { |entry| { dex: entry.dex, covers: entry.covers } }.to_json

  def ld_bodies_slot(count) = tag.span(count, data: { ld_stats_target: "bodies" })

  def owned_line = t("walkthrough.ui.ld_owned_html", caught: body_count_slot, evolved: 0)

  # A species you cannot reach yet at this stop (a rod card before the rod) has no ledger entry, so
  # it is nobody's tick target here. The card still renders, because the species does live here.
  # Registration and the bodies you are holding are both facts about the collection, not about the
  # stop you happen to be reading: catching a Magikarp off Vermilion's dock has to read as caught,
  # and counted, on Viridian's Old Rod card too, four legs before you own the rod. So every card
  # wires up both, taking its cover list from the page's plan entry when there is one and from the
  # game itself when there is not.
  def catch_card_attributes(dex, entry)
    covers = entry ? entry.covers : @game.covers(dex)
    tickable("caught", dex).deep_merge(
      data: { controller: "body-counter", body_counter_game_value: @game.slug,
              body_counter_dex_value: dex, body_counter_covers_value: covers.to_json }
    )
  end

  # A floor row wears the card's own method tag when it reads the same table the card does, so a
  # cave floor says CAVE like the pill above it instead of GRASS, which is only the name of the
  # table underneath. A row on a different table (a Surf spot listed under a grass card) keeps its
  # own label, because there the difference is the whole point of the row.
  def encounter_method_label(place, how = nil)
    place.method?(how) ? how : t("walkthrough.ui.method_#{place.kind}")
  end

  # The ladder's bar runs proportional to the best floor on the card, and a strict CSP blocks the
  # inline width the design mock uses. So the width is bucketed to the nearest 5% and carried as a
  # class: static CSS, no controller, and the exact figure is printed beside the bar anyway. The
  # floor of 5 keeps a 1.2% spawn visible rather than rendering nothing at all.
  FLOOR_BAR_STEP = 5

  def floor_bar_class(place, best)
    share = best.rate.positive? ? (place.rate / best.rate * 100) : 100
    bucket = [ (share / FLOOR_BAR_STEP).round * FLOOR_BAR_STEP, FLOOR_BAR_STEP ].max
    "pn-wt-floors__bar pn-wt-floors__bar--w#{bucket}"
  end

  def catch_spot(entry)
    return t("walkthrough.ui.ld_spot_given", how: entry.how) unless entry.rated?

    key = entry.best? ? "walkthrough.ui.ld_spot_best" : "walkthrough.ui.ld_spot_good"
    t(key, rate: entry.rate)
  end

  # A section inside a band sits under that stop's own h2, so it leads with an h3; a page built
  # around a single stop leads with the h2 itself.
  SECTION_HEADING = { band: [ :h3, "pn-wt-band__h3" ], page: [ :h2, "pn-h2" ] }.freeze

  def wt_heading(text, level)
    name, css = SECTION_HEADING.fetch(level)
    content_tag(name, text, class: css)
  end

  def catch_tally(ids)
    t("walkthrough.ui.catch_tally_html", total: ids.size, done: progress_count(ids))
  end

  def oak_tally(ids)
    t("walkthrough.ui.oak_tally_html", total: ids.size, done: progress_count(ids))
  end

  def ledger_filled(ids)
    t("walkthrough.ui.ld_ledger_filled_html", total: ids.size, filled: progress_count(ids))
  end

  def challenge_why(entry) = t(entry.why_key, **entry.why_args)

  def later_stage_note(later) = t(later.note_key, **later.args)

  def challenge_note_text(note) = t("walkthrough.ui.note_#{note.kind}", **note.args)

  def challenge_note_tag(note) = t("walkthrough.ui.note_tag_#{note.kind}")

  def window_label(window)
    return t("walkthrough.ui.oak_window_label_final") if window.final?

    t("walkthrough.ui.oak_window_label", leader: window.leader.upcase)
  end

  def window_title(window)
    return t("walkthrough.ui.oak_h2_final") if window.final?

    t("walkthrough.ui.oak_h2", leader: window.leader)
  end

  def window_due_label(window)
    return t("walkthrough.ui.oak_due_final") if window.final?

    t("walkthrough.ui.oak_due", leader: window.leader.upcase)
  end

  def modes_off_body(window)
    return t("walkthrough.ui.modes_off_body_final") if window.final?

    t("walkthrough.ui.modes_off_body", leader: window.leader)
  end

  # A trainer is beaten, everything else is collected, so the two tick categories read differently.
  def marker_status_key(marker, state)
    "walkthrough.ui.map_status_#{marker.cat == 'trainer' ? 'trainer' : 'item'}_#{state}"
  end

  # Each gym's background grid takes one of the three identity neon colours, cycling in badge order
  # (Brock magenta, Misty cyan, Lt. Surge amber, then repeat).
  GYM_BADGE_ORDER = %w[BOULDER CASCADE THUNDER RAINBOW SOUL MARSH VOLCANO EARTH].freeze
  GYM_GRID_TONES = %w[magenta cyan amber].freeze

  def gym_grid_tone(badge)
    GYM_GRID_TONES[GYM_BADGE_ORDER.index(badge).to_i % GYM_GRID_TONES.size]
  end

  # A signed friendship-change cell: "+5", "0", or "−5" (a real minus sign, not a hyphen).
  def friendship_delta(value)
    return "0" if value.zero?

    value.positive? ? "+#{value}" : "−#{value.abs}"
  end

  def marker_detail(marker)
    return Walkthrough::PlaceHint.new(marker.place).to_s if marker.place?
    return t("walkthrough.ui.map_exit_#{marker.edge}") if marker.cat == "exit"
    return t("walkthrough.ui.#{marker.note}") if marker.note?

    t("walkthrough.ui.map_cat_#{marker.cat}")
  end

  def best_catch_reason(best, encounter)
    return sole_catch_reason(best, encounter) if best.only
    if best.armed_only
      return t("walkthrough.ui.best_reason_armed_only", name: encounter.name)
    end

    key = best.tie ? "walkthrough.ui.best_reason_tie" : "walkthrough.ui.best_reason_beats"
    t(key, name: encounter.name, rate: best.rate, alt: best.alt_name, alt_rate: best.alt_rate)
  end

  def sole_catch_reason(best, encounter)
    return t("walkthrough.ui.best_reason_only", name: encounter.name) unless best.rate?

    t("walkthrough.ui.best_reason_only_rate", name: encounter.name, rate: best.rate)
  end
end
