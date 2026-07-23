module Walkthrough
  # The sentences a map marker shows for the place behind its door. Every fact comes from
  # Walkthrough::Place (generated out of pokeyellow); this only decides which of them are worth
  # saying and in what order: what the building is, then what it hands you, then what waits inside.
  class PlaceHint
    STOCK_SHOWN = 4

    def initialize(place) = @place = place

    def to_s = lines.join(" ")

    private

    attr_reader :place

    def lines = [ lead, *stock_line, *gift_lines, *count_lines ]

    def lead
      return gym_line if place.gym?
      return phrase("map_place_mart", stock: stock_list) if place.kind == "mart" && place.stock?
      return phrase(place.note) if place.note?

      phrase("map_place_kind_#{place.kind}")
    end

    def gym_line
      gym = place.gym
      phrase("map_place_gym", leader: gym.leader, types: gym.types.join("/"), badge: gym.badge,
        tm: gym.tm)
    end

    # A counter inside something that is not a Mart (the League lobby) still sells, it just is
    # not what the place is for, so its stock trails the sentence that names the building.
    def stock_line
      return [] unless place.stock? && place.kind != "mart"

      [ phrase("map_place_sells", stock: stock_list) ]
    end

    # A department-store counter stocks more than a hint can carry, so the tail is a count.
    def stock_list
      shown = place.stock.take(STOCK_SHOWN).join(", ")
      rest = place.stock.size - STOCK_SHOWN
      rest.positive? ? phrase("map_place_stock_more", stock: shown, count: rest) : shown
    end

    def gift_lines = [ *mon_lines, *item_line ]

    # The Fighting Dojo puts two Pokémon in front of you and lets you keep one.
    def mon_lines
      return [] if place.gift_mon.empty?
      return place.gift_mon.map { |gift| mon_line(gift) } if place.gift_mon.one?

      [ phrase("map_place_gift_choice", names: place.gift_mon.map(&:name).join(phrase("map_place_or")),
        level: place.gift_mon.first.level) ]
    end

    def mon_line(gift)
      key = gift.sold? ? "map_place_sold_mon" : "map_place_gift_mon"
      phrase(key, name: gift.name, level: gift.level)
    end

    def item_line
      return [] unless place.gift_item?

      [ phrase("map_place_gift_item", items: place.gift_item.map { |item| item_name(item) }.join(", ")) ]
    end

    def item_name(item) = item.stack? ? "#{item.qty}× #{item.name}" : item.name

    def count_lines
      counted = []
      counted << phrase("map_place_trainers", count: place.trainers) if place.trainers?
      counted << phrase("map_place_items", count: place.items) if place.items?
      counted
    end

    def phrase(key, **) = I18n.t("walkthrough.ui.#{key}", **)
  end
end
