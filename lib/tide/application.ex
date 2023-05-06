defmodule Tide.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      TideWeb.Telemetry,
      #Start the TZWorld backend
      TzWorld.Backend.EtsWithIndexCache,
      # Start the Ecto repository
      Tide.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Tide.PubSub},
      # Start Finch
      {Finch, name: Tide.Finch},
      # Start the Endpoint (http/https)
      TideWeb.Endpoint
      # Start a worker by calling: Tide.Worker.start_link(arg)
      # {Tide.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tide.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TideWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
