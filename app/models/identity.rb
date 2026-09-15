class Identity < ApplicationRecord
  belongs_to :user

  validates :provider, inclusion: { in: AccountData::OAUTH_PROVIDERS }
  validates :uid, presence: true, uniqueness: { scope: :provider }
end
