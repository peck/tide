defmodule Tide.Repo do
  use Ecto.Repo,
    otp_app: :tide,
    adapter: Ecto.Adapters.SQLite3
end
