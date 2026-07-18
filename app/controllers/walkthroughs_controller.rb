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
end
