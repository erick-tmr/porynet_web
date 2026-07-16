class PagesController < ApplicationController
  def home
    @hero_cells = LandingData.hero_cells
    @features   = LandingData::FEATURES
    @cities     = LandingData::CITIES
    @city_index = LandingData::DEFAULT_CITY_INDEX
    @box_slots  = LandingData.box_slots
    @gens       = LandingData::GENS
  end
end
