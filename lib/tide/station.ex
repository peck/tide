defmodule Tide.Station do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :string, autogenerate: false}
  import Ecto.Query

  schema "stations" do
    field :name, :string
    field :latitude, :float
    field :longitude, :float
    field :time_zone_correction, :integer
    field :time_zone_name, :string
  end

  def get_stations(%{latitude: latitude, longitude: longitude}) do
    Tide.Station
    |> order_by([s], asc: fragment("abs(?)", s.latitude-^latitude) + fragment("abs(?)", s.longitude-^longitude))
    |> Tide.Repo.all()
  end

  @doc false
  def changeset(station, params \\ %{}) do
    station
    |> cast(params, [:id, :name, :latitude, :longitude, :time_zone_correction, :time_zone_name])
    |> validate_required([:id, :name, :latitude, :longitude, :time_zone_correction, :time_zone_name])
  end
end
