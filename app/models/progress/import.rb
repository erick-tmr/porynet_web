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
      wanted = offered.select { |mark_id, on| on && Sync.valid_mark?(mark_id) }.keys.first(MAX_MARKS)
      wanted.each_slice(Sync::MAX_KEYS) { |some| Sync.apply(save_file, marks: some.index_with(true)) }
      wanted.size
    end

    def self.take_bodies(save_file, offered)
      held = Snapshot.bodies(save_file)
      wanted = offered.filter_map do |dex, count|
        [ dex, count.to_i ] if Sync.valid_dex?(dex) && count.to_i > held.fetch(dex, 0)
      end
      wanted.each_slice(Sync::MAX_KEYS) { |some| Sync.apply(save_file, bodies: some.to_h) }
      wanted.sum(&:last)
    end
  end
end
