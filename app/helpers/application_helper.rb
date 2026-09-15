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

  def stop_number(location) = format("%02d", location.order)

  def r2_asset_url(path)
    "#{Rails.application.config.x.r2_public_host}/#{path}"
  end

  def r2_image_tag(path, **options)
    image_tag(r2_asset_url(path), **options)
  end

  ACCOUNT_SECTION_PATHS = { "card" => :account_path, "avatar" => :account_avatar_path,
                            "security" => :account_security_path,
                            "save_file" => :account_save_file_path }.freeze

  def account_section_path(section) = public_send(ACCOUNT_SECTION_PATHS.fetch(section))

  # The authorize route sits outside the locale scope, so the locale rides in the query
  # string instead: OmniAuth hands that back to the callback as omniauth.params.
  def oauth_authorize_path(strategy)
    omniauth_authorize_path(:user, strategy,
                            locale: (I18n.locale unless I18n.locale == I18n.default_locale))
  end

  SOURCE_URLS = {
    showdown: "https://play.pokemonshowdown.com/sprites/trainers/",
    pokeapi: "https://github.com/PokeAPI/sprites",
    pret: "https://github.com/pret"
  }.freeze

  def source_link(name, css)
    link_to t("pages.home.footer.credits_#{name}"), SOURCE_URLS.fetch(name),
            class: css, rel: "noopener", target: "_blank"
  end

  def account_game(save)
    Walkthrough::Versions::CATALOGUE.find { |entry| entry[:slug] == save.slug }
  end

  def account_dex_line(save = AccountData.save_for(nil))
    t("account.chip.dex_line", registered: save.registered, total: AccountData::DEX_TOTAL,
      game: account_game(save)[:name])
  end

  def avatar_image_tag(id, **options)
    avatar = AccountData.avatar(id)
    classes = class_names(options.delete(:class), "pn-art" => avatar.art?)
    r2_image_tag(avatar.key, class: classes.presence, **options)
  end

  STATUS_MOVE_TYPE = "bird".freeze

  def tm_type_desc(mtype)
    return t("walkthrough.ui.tm_status_desc") if mtype == STATUS_MOVE_TYPE

    t("walkthrough.ui.tm_type_desc", type: t("walkthrough.ui.types.#{mtype}"))
  end

  def mart_item_desc(item)
    return t(item.desc_key) if item.desc?

    tm_type_desc(item.mtype)
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
    marks = step_marks(step)
    return t(step.text_key, **marks) unless step.link?

    t(step.text_key, **marks,
      href: walkthrough_leg_path(game: @game.slug, leg: step.link.leg, anchor: step.link.anchor))
  end

  def step_marks(step)
    step.marks.map { |token, key| [ token, map_mark(key, at: step.pins[token]) ] }.to_h
  end

  def shot_caption(step, shot) = t(shot.caption_key, **step_marks(step))

  def trainer_note(trainer)
    return t(trainer.note_key) unless trainer.note_link?

    t(trainer.note_key, href: walkthrough_leg_path(game: @game.slug, leg: trainer.note_link.leg,
      anchor: trainer.note_link.anchor))
  end

  def trivia_intro(trivia)
    t(trivia.intro_key,
      **trivia.marks.map { |token, key| [ token, map_mark(key, at: trivia.pins[token]) ] }.to_h)
  end

  def map_mark(key, at: nil)
    tag.button(key, type: "button", class: "pn-wt-mark",
      title: t("walkthrough.ui.map_marker_hint"),
      data: { action: "click->map-jump#go", mark_key: key, mark_map: at&.split("/")&.first })
  end

  SYNC_ATTEMPTS = 3

  def sync_slot(role)
    tag.span(0, class: "pn-sync__num", data: { sync_banner_target: role })
  end

  def walkthrough_page_controller(game)
    tag.attributes(data: { controller: "progress-toggle mode-toggle map-jump progress-sync",
                           progress_toggle_game_value: game.slug,
                           mode_toggle_game_value: game.slug,
                           progress_sync_game_value: game.slug,
                           **write_through })
  end

  def write_through
    return {} if @sync.nil?

    { progress_sync_url_value: @sync.url, progress_sync_ready_value: @sync.adopted?,
      progress_state: @sync.state.to_json, progress_adopted: @sync.adopted? }
  end

  def tickable(kind, id)
    { role: "button", tabindex: 0, "aria-pressed": "false",
      data: { progress_toggle_target: "item", kind: kind, progress_id: id,
              action: "click->progress-toggle#toggle " \
                      "keydown.enter->progress-toggle#toggle " \
                      "keydown.space->progress-toggle#toggle" } }
  end

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

  def progress_slot(role, ids, kind: "caught", **options)
    options.deep_merge(data: { progress_toggle_target: role, kind: kind,
                               progress_ids: ids.join(" ") })
  end

  def progress_count(ids, kind: "caught") = tag.span(0, **progress_slot("count", ids, kind: kind))

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

  def catch_card_attributes(dex, entry)
    covers = entry ? entry.covers : @game.covers(dex)
    tickable("caught", dex).deep_merge(
      data: { controller: "body-counter", body_counter_game_value: @game.slug,
              body_counter_dex_value: dex, body_counter_covers_value: covers.to_json }
    )
  end

  def encounter_method_label(place, how = nil)
    place.method?(how) ? how : t("walkthrough.ui.method_#{place.kind}")
  end

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

  SECTION_HEADING = { band: [ :h3, "pn-wt-band__h3" ], page: [ :h2, "pn-h2" ] }.freeze

  def wt_heading(text, level)
    name, css = SECTION_HEADING.fetch(level)
    content_tag(name, text, class: css)
  end

  def trainer_floor_chip(floor)
    return if floor.nil?

    tag.span(floor, class: "pn-wt-trainer__floor", title: t("walkthrough.ui.trainer_floor_hint"))
  end

  def catch_tally(ids)
    t("walkthrough.ui.catch_tally_html", total: ids.size, done: progress_count(ids))
  end

  def oak_tally(ids, pick: ids.size)
    t("walkthrough.ui.oak_tally_html", total: pick, done: progress_count(ids))
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

  MARKER_STATUS = { "trainer" => "trainer", "pokemon" => "pokemon" }.freeze

  def marker_status_key(marker, state)
    "walkthrough.ui.map_status_#{MARKER_STATUS.fetch(marker.cat, 'item')}_#{state}"
  end

  GYM_BADGE_ORDER = %w[BOULDER CASCADE THUNDER RAINBOW SOUL MARSH VOLCANO EARTH].freeze
  GYM_GRID_TONES = %w[magenta cyan amber].freeze

  def gym_grid_tone(badge)
    GYM_GRID_TONES[GYM_BADGE_ORDER.index(badge).to_i % GYM_GRID_TONES.size]
  end

  def friendship_delta(value)
    return "0" if value.zero?

    value.positive? ? "+#{value}" : "−#{value.abs}"
  end

  def marker_detail(marker)
    return Walkthrough::PlaceHint.new(marker.place).to_s if marker.place?
    return t("walkthrough.ui.map_exit_#{marker.edge}") if marker.cat == "exit"
    return t("walkthrough.ui.map_hole") if marker.cat == "hole"
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
    return t("walkthrough.ui.best_reason_only_prize", name: encounter.name) if encounter.purchased?
    return t("walkthrough.ui.best_reason_only", name: encounter.name) unless best.rate?

    t("walkthrough.ui.best_reason_only_rate", name: encounter.name, rate: best.rate)
  end

  def catch_stat_label(encounter)
    t(encounter.purchased? ? "walkthrough.ui.coins" : "walkthrough.ui.rate")
  end

  def catch_stat_value(encounter)
    encounter.purchased? ? number_with_delimiter(encounter.rate) : encounter.rate
  end
end
