module Progress
  module Import
    MAX_MARKS = 5_000

    Landed = Data.define(:marks, :bodies)

    def self.call(user, state)
      slugs(state).to_h { |slug| [ slug, merge(user, slug, state) ] }
    end

    def self.slugs(state)
      %w[collected bodies].flat_map { |kind| (state[kind] || {}).keys }.uniq & SaveFile::GAMES
    end

    def self.merge(user, slug, state)
      save_file = SaveFile.for(user, slug)
      Landed.new(marks: take_marks(save_file, state.dig("collected", slug) || {}),
        bodies: take_bodies(save_file, state.dig("bodies", slug) || {}))
    end

    def self.take_marks(save_file, offered)
      wanted = offered.select { |mark_id, on| on && valid_mark?(mark_id) }.keys.first(MAX_MARKS)
      Sync.apply(save_file, marks: wanted.index_with(true)) if wanted.any?
      wanted.size
    end

    def self.valid_mark?(mark_id)
      mark_id.to_s.length <= 96 && mark_id.to_s.match?(WalkthroughMark::MARK_ID)
    end

    def self.take_bodies(save_file, offered)
      held = Snapshot.bodies(save_file)
      wanted = offered.filter_map do |dex, count|
        [ dex, count.to_i ] if valid_dex?(dex) && count.to_i > held.fetch(dex, 0)
      end
      Sync.apply(save_file, bodies: wanted.to_h) if wanted.any?
      wanted.sum(&:last)
    end

    def self.valid_dex?(dex) = dex.to_s.match?(/\A\d{3}\z/)
  end
end
