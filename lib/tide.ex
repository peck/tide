defmodule Tide do
  require Finch
  require Logger
  import Ecto.Query

  @doc """
  Query the National Oceanic and Atmospheric Administration (NOAA) for tide predictions for the next 24 hours.
  """

  def get_tide(latitude, longitude) do
    {:ok, station} = get_nearest_station(latitude, longitude)
    date = Date.utc_today()
    get_tide_by_station(station, date)
  end

  def get_tide_by_station(station = %Tide.Station{}, date) do
    with {:ok, predictions} <- tide_predictions(station, date),
         {:ok, events} <- get_astronomy(station.latitude, station.longitude, date) do
      events =
        Enum.map(events, fn {event, utc_time} ->
          {event, DateTime.shift_zone!(utc_time, station.time_zone_name)}
        end)
        |> Enum.into(%{})

      predictions = Enum.map(predictions, fn(prediction) ->
                                            %{prediction | timestamp: DateTime.shift_zone!(prediction.timestamp, station.time_zone_name)}
                                            end)

      {:ok, %{station: station, predictions: predictions, events: events}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def tide_predictions(station, date = %Date{}) do
    {:ok, Tide.Prediction.get_predictions(station, date)}
  end

  def get_nearest_station(latitude, longitude) do
    {:ok,
     Tide.Station
     |> order_by([s],
     asc:
     fragment("abs(?)", s.latitude - ^latitude) + fragment("abs(?)", s.longitude - ^longitude)
     )
     |> limit(1)
     |> Tide.Repo.one()}
  end

  def populate_stations() do
    {:ok, stations} = get_stations()

    changesets =
      Enum.map(
        stations,
        fn station ->
          {:ok, station_local_timezone} =
            TzWorld.timezone_at({station["longitude"], station["latitude"]})

          station = Map.put(station, "time_zone_name", station_local_timezone)
          Tide.Station.changeset(%Tide.Station{}, station)
        end
      )

    Tide.Repo.transaction(fn ->
      Enum.each(changesets, fn cs -> Tide.Repo.insert(cs) end)
    end)
  end

  def datetime_at_station(station = %Tide.Station{}) do
    DateTime.now!(station.time_zone_name)
  end

  def get_stations() do
    url = "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json"

    params =
      %{
        "type" => "tidepredictions",
        "units" => "english"
      }
      |> URI.encode_query()

    uri = URI.parse(url)

    uri = %{uri | query: params}

    req = Finch.build(:get, uri)

    case Finch.request(req, Tide.Finch) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body |> Jason.decode!() |> Map.get("stations") |> Enum.map(&parse_station/1)}

      {:ok, %{status: code, body: body}} ->
        {:error, "HTTP error #{code}: #{body}"}

      {:error, reason} ->
        {:error, "HTTP error: #{reason}"}
    end
  end

  def get_astronomy(latitude, longitude, date) do
    url = "https://aa.usno.navy.mil/api/rstt/oneday"

    params =
      %{
        "date" => Calendar.strftime(date, "%Y-%m-%d"),
        "coords" => "#{latitude},#{longitude}"
      }
      |> URI.encode_query()

    uri = URI.parse(url)

    uri = %{uri | query: params}

    {_cachex_result, res} =
      Cachex.fetch(:prediction_cache, uri, fn uri ->
        req = Finch.build(:get, uri)

        case Finch.request(req, Tide.Finch) do
          {:ok, %{status: 200, body: body}} ->
            res = body |> Jason.decode!() |> parse_astronomy

            events =
            for {key, value} <- res do
              datetime_str = "#{Calendar.strftime(date, "%Y-%m-%d")}T#{value}:00Z"
              {:ok, datetime, _} = DateTime.from_iso8601(datetime_str)
              {key, datetime}
            end
            |> Map.new()

            {:commit, {:ok, events}}

          {:ok, %{status: code, body: body}} ->
            {:ignore, {:error, "HTTP error #{code}: #{body}"}}

          {:error, reason} ->
            {:ignore, {:error, "HTTP error: #{reason}"}}
        end
      end)

    res
  end

  # Parse the sunrise, sunset, moonrise, and moonset times and convert to DateTime
  defp parse_astronomy(response) do
    %{
      sunrise:
      get_in(response, ["properties", "data", "sundata"])
      |> Enum.find(fn x -> x["phen"] == "Rise" end)
      |> Map.get("time"),
      sunset:
      get_in(response, ["properties", "data", "sundata"])
      |> Enum.find(fn x -> x["phen"] == "Set" end)
      |> Map.get("time"),
      moonrise:
      get_in(response, ["properties", "data", "moondata"])
      |> Enum.find(%{}, fn x -> x["phen"] == "Rise" end)
      |> Map.get("time"),
      moonset:
      get_in(response, ["properties", "data", "moondata"])
      |> Enum.find(%{}, fn x -> x["phen"] == "Set" end)
      |> Map.get("time")
    }
    |> Enum.reject(fn {_key, value} -> value == nil end)
    |> Enum.into(%{})
  end

  defp parse_station(station) do
    %{
      "id" => station["id"],
      "latitude" => station["lat"],
      "longitude" => station["lng"],
      "name" => station["name"],
      "time_zone_correction" => station["timezonecorr"]
    }
  end

  def encode_to_csv(tide_data, file_path) do
    # Convert the tide data to a list of lists (i.e., rows of CSV data)
    csv_data = 
      tide_data 
      |> Enum.map(fn %{"t" => datetime, "type" => tide_type, "v" => level} -> 
      [DateTime.to_string(datetime), tide_type, level] 
    end)

      # Add header row
      csv_data = [["datetime", "tide_type", "level"]] ++ csv_data

      {:ok, file} = File.open(file_path, [:write])
      encoded_data = CSV.encode(csv_data)
      Enum.each(encoded_data, &IO.write(file, &1))
      File.close(file)
  end
end
