require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Workspace
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    %w[models controllers services].each do |directory|
      path = Rails.root.join("finance_module/app", directory)
      config.autoload_paths << path
      config.eager_load_paths << path
    end
    config.autoload_paths << Rails.root.join("finance_module/lib")
    config.eager_load_paths << Rails.root.join("finance_module/lib")
    config.paths["db/migrate"] << Rails.root.join("finance_module/db/migrate")
    config.paths["app/views"] << Rails.root.join("finance_module/app/views")
    config.time_zone = ENV.fetch("DASHBOARD_TIME_ZONE", "Europe/Istanbul")

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
