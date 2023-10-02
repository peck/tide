# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :tide, Tide.Repo,
  database: "priv/tide.db",
  pool_size: 10,
  journal_mode: :off

config :tide, ecto_repos: [Tide.Repo]

# Configures the endpoint
config :tide, TideWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: TideWeb.ErrorHTML, json: TideWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Tide.PubSub,
  live_view: [signing_salt: "M0SU6/jl"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :tide, Tide.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.2.7",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :elixir, :time_zone_database, Tz.TimeZoneDatabase

config :tide, stations_per_request: 10

#config :tz_world,
  # The default is the `priv` directory of `:tz_world`
  #data_dir: "priv/tz_world_data"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
