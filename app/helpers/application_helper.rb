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
end
