class LocationsController < ApplicationController
  allow_unauthenticated_access only: %i[show]
  # A forecast is only worth showing once someone has told us where they live;
  # the management screens stay reachable so the first location can be added.
  before_action :require_current_location, only: %i[show]
  before_action :set_location, only: %i[edit update destroy refresh]

  def index
    @locations = Location.by_name
  end

  # The Wii-style paneled forecast, at /locations/:slug. The root path redirects
  # here for the visitor's own location (see HomeController).
  def show
    @location = Location.find_by!(slug: params[:slug])
    # Viewing your own location sends the Globe button home (centred on it);
    # any other location's Globe button resumes the saved map view.
    @is_current_location = @location.id == current_location.id
    # Somewhere people actually look stays in the hourly refresh tier.
    @location.mark_viewed!
  end

  # Prefilled from params when a geocoding search result is picked so the
  # operator can review the captured coordinates before saving.
  def new
    @location = Location.new(prefill_params)
  end

  def create
    @location = Location.new(location_params)

    if @location.save
      # Broadcast from here rather than a model callback: db/seeds.rb builds its
      # ~300 cities through the model, and a callback would announce every one
      # of them. Admin CRUD is the only time a location appears or disappears
      # while someone might be watching the globe.
      WeatherBroadcast.locations_changed
      redirect_to locations_path, notice: "#{@location.name} was added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @location.update(location_params)
      # A rename moves the marker's label and its slug (and so the URL the globe
      # clicks through to); a coordinate edit moves the marker itself.
      WeatherBroadcast.locations_changed
      redirect_to locations_path, notice: "#{@location.name} was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @location.destroy
    WeatherBroadcast.locations_changed
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
    @location = Location.find_by!(slug: params[:slug])
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
