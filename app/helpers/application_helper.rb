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

  def poke_dollar(amount)
    tag.span(class: "pn-money-value") do
      safe_join([
        tag.span(nil, class: "pn-money", role: "img", "aria-label": t("walkthrough.ui.poke_dollar")),
        tag.span(number_with_delimiter(amount), class: "pn-money-value__n")
      ])
    end
  end

  def step_text(step)
    return t(step.text_key) unless step.link?

    t(step.text_key, href: walkthrough_leg_path(game: @game.slug, leg: step.link.leg, anchor: step.link.anchor))
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

  # Both captions render up front and CSS picks one, so no user-visible string lives in JS and
  # the toast cannot get stuck showing the wrong half of the pair.
  def progress_toast(flavor)
    tag.span(class: "pn-wt-toast", aria: { live: "polite" }) do
      safe_join(%w[todo done].map do |state|
        tag.span(t("walkthrough.ui.map_status_#{flavor}_#{state}"), class: "pn-wt-toast__#{state}")
      end)
    end
  end

  def progress_count(kind, ids)
    tag.span(0, data: { progress_toggle_target: "count", kind: kind, progress_ids: ids.join(" ") })
  end

  # A trainer is beaten, everything else is collected, so the two tick categories read differently.
  def marker_status_key(marker, state)
    "walkthrough.ui.map_status_#{marker.cat == 'trainer' ? 'trainer' : 'item'}_#{state}"
  end

  def marker_detail(marker)
    return t("walkthrough.ui.map_exit_#{marker.edge}") if marker.cat == "exit"
    return t("walkthrough.ui.#{marker.note}") if marker.note?

    t("walkthrough.ui.map_cat_#{marker.cat}")
  end

  def best_catch_reason(best, encounter)
    return sole_catch_reason(best, encounter) if best.only

    key = best.tie ? "walkthrough.ui.best_reason_tie" : "walkthrough.ui.best_reason_beats"
    t(key, name: encounter.name, rate: best.rate, alt: best.alt_name, alt_rate: best.alt_rate)
  end

  def sole_catch_reason(best, encounter)
    return t("walkthrough.ui.best_reason_only", name: encounter.name) unless best.rate?

    t("walkthrough.ui.best_reason_only_rate", name: encounter.name, rate: best.rate)
  end
end
