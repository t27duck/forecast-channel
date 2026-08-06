Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # The install manifest, from app/views/pwa/manifest.json.erb (linked in the
  # layout's head). Rails::PwaController inherits Rails::ApplicationController —
  # *not* this app's ApplicationController — so neither the fail-closed
  # require_authentication nor require_current_location applies to it. That's
  # what makes it reachable at all: a browser fetches the manifest before anyone
  # has signed in or chosen a location. test/integration/pwa_test.rb pins it.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # The offline cache, from app/views/pwa/service-worker.js.erb — same story as
  # the manifest above, and registered by app/javascript/lib/pwa.js. Served from
  # the root, without an extension, so its scope covers the whole app; the
  # format has to be declared here instead, or the request asks for :html and
  # the .js.erb template doesn't match.
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker,
    defaults: { format: :js }

  resource :session

  resource :map, only: [ :show ]
  get "map/markers", to: "maps#markers", as: :map_markers

  resource :settings, only: [ :show, :update ]
  namespace :settings do
    # Choose the closest location: pick a country, then a location in it.
    resource :location, only: [ :show, :update ]
  end

  # Sets the closest location from the browser's geolocation, then shows it.
  resource :current_location, only: [ :create ]

  # Background-music tracks (admin only).
  resources :sounds, except: %i[show]

  # Solid Queue dashboard (admin only — its controllers inherit
  # ApplicationController, so the app's sign-in guards it; see
  # config/initializers/mission_control_jobs.rb).
  mount MissionControl::Jobs::Engine, at: "/jobs"

  # Addressed by slug (Location#to_param), so the segment is :slug, not :id.
  resources :locations, param: :slug do
    get :search, on: :collection
    post :refresh_all, on: :collection
    post :refresh, on: :member
  end

  # The entry point: redirects to the current location's forecast (or to the
  # picker when there isn't one yet). The globe lives at /map.
  root "home#show"
end
