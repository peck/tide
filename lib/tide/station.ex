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
    field :distance, :float, virtual: true
    has_many :predictions, Tide.Prediction
  end

  def get_stations_by_distance(latitude, longitude, limit \\ 10, offset \\ 0) do
    query = """
    SELECT *,
      (
        6371000 * acos(
          cos((? * 1.0 * pi() / 180)) *
          cos((latitude * 1.0 * pi() / 180)) *
          cos((longitude * 1.0 * pi() / 180) - (? * 1.0 * pi() / 180)) +
          sin((? * 1.0 * pi() / 180)) *
          sin((latitude * 1.0 * pi() / 180))
        )
      ) AS distance
    FROM stations
    ORDER BY distance
    LIMIT ?
    OFFSET ?;
    """

    #Tide.Repo.query(query, [latitude, longitude, latitude])

    case Tide.Repo.query(query, [latitude, longitude, latitude, limit, offset]) do
      {:ok, result} ->
        {:ok,
         Enum.map(
           result.rows,
           &Tide.Repo.load(
             Tide.Station.__schema__(:load) |> Enum.into(%{distance: :float}),
             {result.columns, &1}
           )
         )}

      {:error, error} ->
        {:error, error}
    end
  end

  def get_stations(%{latitude: latitude, longitude: longitude}) do
    q =
      from s in Tide.Station,
        order_by: [
          asc:
            fragment(
              """
                6371000 * acos(
                  cos((? * 1.0 * pi() / 180)) *
                  cos((? * 1.0 * pi() / 180)) *
                  cos((? * 1.0 * pi() / 180) - (? * 1.0 * pi() / 180)) +
                  sin((? * 1.0 * pi() / 180)) *
                  sin((? * 1.0 * pi() / 180))
                )
              """,
              ^latitude,
              s.latitude,
              s.longitude,
              ^longitude,
              ^longitude,
              s.latitude
            )
        ],
        select: %{
          name: s.name,
          distance:
            fragment(
              """
                6371000 * acos(
                  cos((? * 1.0 * pi() / 180)) *
                  cos((? * 1.0 * pi() / 180)) *
                  cos((? * 1.0 * pi() / 180) - (? * 1.0 * pi() / 180)) +
                  sin((? * 1.0 * pi() / 180)) *
                  sin((? * 1.0 * pi() / 180))
                )
              """,
              ^latitude,
              s.latitude,
              s.longitude,
              ^longitude,
              ^longitude,
              s.latitude
            )
            |> selected_as(:distance)
        }

    Tide.Repo.all(q)
  end

  @doc false
  def changeset(station, params \\ %{}) do
    station
    |> cast(params, [:id, :name, :latitude, :longitude, :time_zone_correction, :time_zone_name])
    |> validate_required([
      :id,
      :name,
      :latitude,
      :longitude,
      :time_zone_correction,
      :time_zone_name
    ])
  end
end
