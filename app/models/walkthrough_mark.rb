class WalkthroughMark < ApplicationRecord
  MARK_ID = %r{\A[a-z0-9][a-z0-9-]*/[a-z0-9][a-z0-9-]*\z}

  belongs_to :save_file

  validates :mark_id, format: { with: MARK_ID }, length: { maximum: 96 },
                      uniqueness: { scope: :save_file_id }
end
