module Progress
  module Import
    Landed = Data.define(:marks, :bodies)

    def self.batch(save_file, collected: {}, bodies: {})
      marks = wanted_marks(collected)
      raised = wanted_bodies(save_file, bodies)
      Sync.apply(save_file, marks: marks.index_with(true), bodies: raised)
      Landed.new(marks: marks.size, bodies: raised.values.sum)
    end

    def self.wanted_marks(offered)
      offered.select { |mark_id, on| on && valid_mark?(mark_id) }.keys
    end

    def self.valid_mark?(mark_id)
      mark_id.to_s.length <= 96 && mark_id.to_s.match?(WalkthroughMark::MARK_ID)
    end

    def self.wanted_bodies(save_file, offered)
      held = Snapshot.bodies(save_file)
      offered.filter_map do |dex, count|
        [ dex, count.to_i ] if valid_dex?(dex) && count.to_i > held.fetch(dex, 0)
      end.to_h
    end

    def self.valid_dex?(dex) = dex.to_s.match?(/\A\d{3}\z/)
  end
end
