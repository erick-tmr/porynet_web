class Pokemon < ApplicationRecord
  # A box holds far fewer than this. It is here so one request cannot ask for a million rows.
  MAX_PER_SAVE = 999

  belongs_to :save_file
  has_many :blocks, class_name: "PokemonBlock"

  validates :national_dex, format: { with: /\A\d{3}\z/ }
  validates :origin_context, inclusion: { in: Context::ALL }

  scope :of_species, ->(dex) { where(national_dex: dex) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # Nothing but a body: the walkthrough was ticked, and no save file has filled it in yet. Derived
  # rather than stored, so a block or a nickname arriving cannot leave a stale flag behind.
  def placeholder? = nickname.nil? && blocks.none?

  # A Pokemon the trainer caught themselves carries no OT of its own and answers with the save
  # file's, which stays right when the save file learns its name later. One that arrived from
  # somebody else carries theirs, and that is what makes it a traded Pokemon.
  def original_trainer = ot_name || save_file.ot_name

  def traded? = ot_name.present? && ot_name != save_file.ot_name
end
