module Walkthrough
  Encounter = Data.define(:dex, :name, :how, :rate, :level, :rarity, :tip_key, :evo_line) do
    def gift? = %w[GIFT STARTER TRADE].include?(how)
    def wild? = !gift?
  end

  Item = Data.define(:name, :where_key)
  HiddenItem = Data.define(:name, :where_key, :image, :pin)
  Shot = Data.define(:image, :label)

  Step = Data.define(:n, :title_key, :text_key, :items, :hidden, :shot) do
    def items? = items.any?
    def hidden? = hidden.any?
    def shot? = !shot.nil?
  end

  Trainer = Data.define(:cls, :name, :reward, :team) # team: [{ dex:, name:, lvl: }]
  OakEntry = Data.define(:dex, :name, :qty, :why_key)

  Location = Data.define(
    :slug, :kind, :name, :order, :note_key, :intro_key, :badge,
    :steps, :encounters, :trainers, :oak_queue
  ) do
    def dex_list = encounters.map(&:dex)
    def wild_encounters = encounters.select(&:wild?)
    def catchable_count = wild_encounters.size
    def badge? = !badge.nil?
  end

  Game = Data.define(:slug, :name, :region, :dex_goal, :oak_queue, :locations) do
    def location(slug) = locations.find { |loc| loc.slug == slug }

    def location!(slug)
      location(slug) || raise(ActiveRecord::RecordNotFound, "Unknown #{self.slug} location: #{slug}")
    end

    def previous(loc) = neighbor(loc, -1)
    def following(loc) = neighbor(loc, 1)

    def obtainable_dex = locations.flat_map(&:dex_list).uniq

    def obtainable_upto(loc)
      idx = locations.index(loc)
      locations.first(idx + 1).flat_map(&:dex_list).uniq
    end

    def new_dex_for(loc)
      idx = locations.index(loc)
      loc.dex_list - locations.first(idx).flat_map(&:dex_list)
    end

    private

    def neighbor(loc, delta)
      pos = locations.index(loc) + delta
      return nil if pos.negative? || pos >= locations.size

      locations[pos]
    end
  end

  def self.games = { "yellow" => Yellow.game }

  def self.find(slug) = games[slug]

  def self.find!(slug)
    find(slug) || raise(ActiveRecord::RecordNotFound, "No walkthrough for game: #{slug}")
  end
end
