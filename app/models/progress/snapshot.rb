module Progress
  module Snapshot
    def self.marks(save_file) = save_file.walkthrough_marks.order(:mark_id).pluck(:mark_id)

    def self.bodies(save_file) = save_file.pokemon.group(:national_dex).count
  end
end
