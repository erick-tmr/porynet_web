class WalkthroughsController < ApplicationController
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
end
