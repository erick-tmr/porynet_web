class SaveFile < ApplicationRecord
  GAMES = Walkthrough::Versions::CATALOGUE.map { |entry| entry[:slug] }.freeze

  belongs_to :user
  has_many :walkthrough_marks
  has_many :pokemon

  # One save file per game, held by the unique index rather than a validation: create_or_find_by!
  # settles a race by letting the insert fail, which a validation would pre-empt and turn into an
  # exception instead.
  validates :game_slug, inclusion: { in: GAMES }

  def self.for(user, game_slug)
    raise ActiveRecord::RecordNotFound unless GAMES.include?(game_slug)

    create_or_find_by!(user: user, game_slug: game_slug)
  end
end
