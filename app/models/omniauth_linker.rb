class OmniauthLinker
  Result = Data.define(:status, :user, :email, :provider)

  def initialize(auth, current_user = nil)
    @auth = auth
    @current_user = current_user
  end

  def call
    return build(:unverified) if verified_email.blank?
    return link if current_user

    identity = identity_for_uid
    return build(:signed_in, user: identity.user) if identity
    return build(:email_taken) if User.exists?(email: verified_email)

    build(:signup)
  end

  def credentials = { "provider" => provider, "uid" => uid, "email" => verified_email }

  private

  attr_reader :auth, :current_user

  def link
    identity = identity_for_uid
    return build(:taken) if identity && identity.user_id != current_user.id
    return build(:linked, user: current_user) if identity
    return build(:already_connected) if current_user.identities.exists?(provider: provider)

    current_user.identities.create!(provider: provider, uid: uid, email: verified_email)
    build(:linked, user: current_user)
  end

  def identity_for_uid = Identity.find_by(provider: provider, uid: uid)

  def provider = AccountData.oauth_provider(auth.provider)

  def uid = auth.uid.to_s

  def verified_email
    return @verified_email if defined?(@verified_email)

    @verified_email = confirmed_address
  end

  # The strategy nils out info.email unless Google verified it, and prunes the key
  # entirely rather than setting it false, so presence is the check. id_info carries the
  # same claim from a token whose signature the strategy checked, whenever openid came back.
  def confirmed_address
    claim = auth.extra&.id_info
    return if claim && !claim["email_verified"]

    auth.info.email.presence
  end

  def build(status, user: nil)
    Result.new(status: status, user: user, email: verified_email, provider: provider)
  end
end
