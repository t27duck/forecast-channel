class LocationsController < ApplicationController
  before_action :set_location, only: %i[show edit update destroy refresh]

  def index
    @locations = Location.by_name
  end

  # The Wii-style paneled forecast for a single location.
  def show
  end

  # Prefilled from params when a geocoding search result is picked so the
  # operator can review the captured coordinates before saving.
  def new
    @location = Location.new(prefill_params)
  end

  def create
    @location = Location.new(location_params)

    if @location.save
      redirect_to locations_path, notice: "#{@location.name} was added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @location.update(location_params)
      redirect_to locations_path, notice: "#{@location.name} was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @location.destroy
    redirect_to locations_path, notice: "#{@location.name} was removed."
  end

  # Geocoding proxy: renders the search-results Turbo Frame for the new form.
  def search
    @query = params[:query].to_s
    @results = OpenMeteo::GeocodingClient.search(@query)
  end

  # Refresh a single location's weather now (synchronous for immediate feedback).
  def refresh
    if @location.refresh_weather!
      redirect_to locations_path, notice: "#{@location.name}'s weather was refreshed."
    else
      redirect_to locations_path, alert: "Couldn't reach the weather service for #{@location.name}."
    end
  end

  # Enqueue a background refresh for every location.
  def refresh_all
    RefreshAllWeatherJob.perform_later
    redirect_to locations_path, notice: "Refreshing weather for all locations…"
  end

  private

  def set_location
    @location = Location.find(params[:id])
  end

  def location_params
    params.require(:location).permit(
      :name, :latitude, :longitude, :country, :country_code,
      :admin1, :timezone, :elevation, :population, :open_meteo_id
    )
  end

  # Same permitted attributes, but tolerant of an absent :location key so the
  # blank new form still renders.
  def prefill_params
    return {} unless params[:location]

    location_params
  end
end
