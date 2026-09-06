class User < ApplicationRecord
  AVATARS = AccountData.avatar_ids
  TRAINER_NAME_FORMAT = /\A[A-Za-z0-9_.-]{2,12}\z/

  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :validatable,
         authentication_keys: [ :login ]

  attr_writer :login
  attr_accessor :terms

  normalizes :trainer_name, with: ->(name) { name.strip }

  validates :trainer_name, presence: true,
                           format: { with: TRAINER_NAME_FORMAT },
                           uniqueness: { case_sensitive: false }
  validates :avatar, inclusion: { in: AVATARS }
  validates :email, confirmation: true
  validates :terms, acceptance: { allow_nil: false }, on: :create

  before_validation :stamp_terms_accepted, on: :create

  def login
    @login || trainer_name
  end

  def self.find_for_database_authentication(conditions)
    login = conditions[:login].to_s.strip.downcase
    return if login.blank?

    where("lower(trainer_name) = :login OR lower(email) = :login", login: login).first
  end

  private

  def stamp_terms_accepted
    self.terms_accepted_at ||= Time.current
  end
end
