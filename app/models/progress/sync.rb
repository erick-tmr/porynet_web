module Progress
  module Sync
    MAX_KEYS = 64
    MAX_BODIES = 999

    def self.apply(save_file, marks: {}, bodies: {})
      save_file.with_lock do
        marks.first(MAX_KEYS).each do |mark_id, on|
          on ? add_mark(save_file, mark_id) : drop_mark(save_file, mark_id)
        end
        bodies.first(MAX_KEYS).to_h { |dex, count| [ dex, hold(save_file, dex, count) ] }
      end
    end

    def self.add_mark(save_file, mark_id)
      WalkthroughMark.insert_all(
        [ { save_file_id: save_file.id, mark_id: mark_id, created_at: Time.current } ],
        unique_by: :index_walkthrough_marks_on_save_file_id_and_mark_id
      )
      receive_trade(save_file, mark_id)
    end

    def self.drop_mark(save_file, mark_id)
      save_file.walkthrough_marks.where(mark_id: mark_id).delete_all
      trade = trade_at(save_file, mark_id)
      traded_in(save_file, trade).delete_all if trade
    end

    def self.receive_trade(save_file, mark_id)
      trade = trade_at(save_file, mark_id)
      return if trade.nil? || traded_in(save_file, trade).exists?

      save_file.pokemon.create!(national_dex: trade.receive[:dex], nickname: trade.nick,
        ot_name: trade.ot_name, **origin(save_file))
    end

    def self.trade_at(save_file, mark_id) = Walkthrough.trades_for(save_file.game_slug)[mark_id]

    def self.traded_in(save_file, trade)
      save_file.pokemon.where(national_dex: trade.receive[:dex], nickname: trade.nick,
        ot_name: trade.ot_name)
    end

    def self.hold(save_file, dex, want)
      held = save_file.pokemon.of_species(dex)
      gap = want.to_i.clamp(0, MAX_BODIES) - held.count
      gap.positive? ? add_bodies(save_file, dex, gap) : release(held, -gap)
      held.count
    end

    def self.add_bodies(save_file, dex, count)
      now = Time.current
      Pokemon.insert_all(Array.new(count) do
        { save_file_id: save_file.id, national_dex: dex, created_at: now, updated_at: now,
          **origin(save_file) }
      end)
    end

    def self.release(held, count)
      return if count.zero?

      Pokemon.where(id: held.where(nickname: nil).where.missing(:blocks)
        .newest_first.limit(count).ids).delete_all
    end

    def self.origin(save_file)
      { origin_context: Pokemon::Context.for(save_file.game_slug),
        origin_game_slug: save_file.game_slug }
    end
  end
end
