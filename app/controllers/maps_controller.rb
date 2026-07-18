class MapsController < ApplicationController
  def show
    @locations = Location.by_name
  end
end
