class WalkthroughMark < ApplicationRecord
  # A place and the thing on it: "route-2/item-13-54". A species is not a mark, it is a Pokemon,
  # so nothing here is a bare dex number.
  MARK_ID = %r{\A[a-z0-9][a-z0-9-]*/[a-z0-9][a-z0-9-]*\z}

  belongs_to :save_file

  validates :mark_id, format: { with: MARK_ID }, length: { maximum: 96 },
                      uniqueness: { scope: :save_file_id }
end
