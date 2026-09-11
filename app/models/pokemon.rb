class Pokemon < ApplicationRecord
  belongs_to :save_file
  has_many :blocks, class_name: "PokemonBlock"

  validates :national_dex, format: { with: /\A\d{3}\z/ }
  validates :origin_context, inclusion: { in: Context::ALL }

  scope :of_species, ->(dex) { where(national_dex: dex) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def placeholder? = nickname.nil? && blocks.none?

  def original_trainer = ot_name || save_file.ot_name

  def traded? = ot_name.present? && ot_name != save_file.ot_name
end
