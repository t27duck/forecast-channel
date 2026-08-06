module PwaHelper
  # The service worker's cache generation, interpolated into the worker script.
  #
  # Taken from Propshaft's digested paths for the two build outputs, so it turns
  # over exactly when the JavaScript or CSS changes — which is exactly when a
  # cached asset has gone stale. A deploy that only touched ERB leaves it alone,
  # and rightly so: pages are fetched network-first, only assets are cached
  # first.
  #
  # Not a git SHA or a deploy id, which would rotate on every deploy and throw
  # away a perfectly good asset cache each time (and would need env plumbing
  # that development and test haven't got). Not `config.assets.version` either,
  # which is a constant somebody has to remember to bump. This needs no
  # remembering, and it works the same in development, where editing a
  # stylesheet during `bin/dev` rotates the cache on its own.
  #
  # Available inside app/views/pwa/* because Rails::ApplicationController
  # inherits straight from ActionController::Base, which is what makes Rails
  # give it `helper :all`.
  def service_worker_version
    Digest::SHA256.hexdigest(
      [ asset_path("application.js"), asset_path("application.css") ].join
    ).first(12)
  end
end
