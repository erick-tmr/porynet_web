class SaveFile < ApplicationRecord
  GAMES = Walkthrough::Versions::CATALOGUE.map { |entry| entry[:slug] }.freeze

  belongs_to :user
  has_many :walkthrough_marks
  has_many :pokemon

  validates :game_slug, inclusion: { in: GAMES }

  def self.for(user, game_slug)
    raise ActiveRecord::RecordNotFound unless GAMES.include?(game_slug)

    find_by(user: user, game_slug: game_slug) || start_fresh(user, game_slug)
  end

  def self.start_fresh(user, game_slug)
    create_or_find_by!(user: user, game_slug: game_slug) { |file| file.imported_at = Time.current }
  end
end
