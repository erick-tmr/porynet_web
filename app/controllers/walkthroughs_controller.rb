class WalkthroughsController < ApplicationController
  before_action :check_sync, only: %i[show leg mew_glitch]

  def index
    @versions = Walkthrough::Versions.all
  end

  def show
    @game = Walkthrough.find!(params[:game])
  end

  def leg
    @game = Walkthrough.find!(params[:game])
    @leg = @game.leg!(params[:leg])
    if @leg.special
      @location = @leg.locations.first
      render :special
    else
      render :leg
    end
  end

  def mew_glitch
    @game = Walkthrough.find!(params[:game])
    @guide = Walkthrough::Yellow.mew_glitch
  end

  private

  def check_sync
    return unless user_signed_in?

    save_file = SaveFile.find_by(user: current_user, game_slug: params[:game])
    @sync = Progress::Handover.new(pending: save_file&.imported_at.nil?,
      url: walkthrough_progress_path(game: params[:game]),
      state: Progress::Snapshot.state(save_file, params[:game]))
  end
end
