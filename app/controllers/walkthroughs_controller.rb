class WalkthroughsController < ApplicationController
  def show
    @game = Walkthrough.find!(params[:game])
  end

  def location
    @game = Walkthrough.find!(params[:game])
    @location = @game.location!(params[:location])
  end
end
