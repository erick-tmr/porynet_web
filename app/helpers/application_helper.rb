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
end
