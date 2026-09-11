module Progress
  module Snapshot
    def self.marks(save_file) = save_file.walkthrough_marks.order(:mark_id).pluck(:mark_id)

    def self.bodies(save_file) = save_file.pokemon.group(:national_dex).count

    def self.state(save_file, game_slug)
      return empty(game_slug) if save_file.nil?

      held = bodies(save_file)
      { collected: { game_slug => marks(save_file).index_with(true) },
        caught: { game_slug => held.keys.index_with(true) },
        bodies: { game_slug => held } }
    end

    def self.empty(game_slug)
      { collected: { game_slug => {} }, caught: { game_slug => {} },
        bodies: { game_slug => {} } }
    end
  end
end
