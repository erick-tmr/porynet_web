module OauthStash
  extend ActiveSupport::Concern

  KEY = "pending_oauth".freeze
  WINDOW = 15.minutes

  private

  def stash_oauth(credentials)
    session[KEY] = credentials.merge("at" => Time.current.to_i)
  end

  def pending_oauth
    stash = session[KEY]
    return if stash.blank? || stash["at"].to_i < WINDOW.ago.to_i

    stash
  end

  def clear_oauth_stash = session.delete(KEY)
end
