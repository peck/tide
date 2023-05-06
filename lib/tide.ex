defmodule Tide do
  require Finch
  require Logger
  import Ecto.Query

  @doc """
  Query the National Oceanic and Atmospheric Administration (NOAA) for tide predictions for the next 24 hours.
  """

  def get_tide(latitude, longitude) do
    {:ok, station} = get_nearest_station(latitude, longitude)
    date = datetime_at_station(station)
    get_tide_by_station(station, date)
  end

  def get_tide_by_station(station = %Tide.Station{}, date) do
    with {:ok, predictions} <- tide_predictions(station.id, date),
         {:ok, events} <- get_astronomy_times(station.latitude, station.longitude, date) do
      #localize the predictions

      #predictions = Enum.map(predictions, fn(x) ->
      #  {_old, new} = Map.get_and_update(x, "t",
      #  fn(t) -> {t, DateTime.shift_zone!(t, station.time_zone_name)} end
      #)
      #  {_old, new} = Map.get_and_update(new, "t_truncated",
      #    fn(t) -> {t, DateTime.shift_zone!(t, station.time_zone_name)} end
      #  )
      #  new
      #end)

      events = Enum.map(events, fn({event, utc_time}) ->
        {event, DateTime.shift_zone!(utc_time, station.time_zone_name)}
      end) |> Enum.into(%{})

      {:ok, %{station: station, predictions: predictions, events: events}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def tide_predictions(station_id, date = %Date{}) do
    datetime = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    tide_predictions(station_id, datetime)
  end

  def tide_predictions(station_id, date_time = %DateTime{}) do
    station = Tide.Repo.get_by(Tide.Station, id: station_id)
    url = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
    params = %{
      "begin_date" => Calendar.strftime(date_time, "%Y%m%d"),
      "end_date" => Calendar.strftime(date_time, "%Y%m%d"),
      "station" => station.id,
      "product" => "predictions",
      "datum" => "MLLW",
      "interval" => "hilo",
      "units" => "english",
      "time_zone" => "lst_ldt",
      "format" => "json"
    } |> URI.encode_query

    uri = URI.parse(url)

    uri = %{uri | query: params}
    {_cachex_result, res} = Cachex.fetch(:prediction_cache, uri, fn(uri) ->
        req = Finch.build(:get, uri)
        case Finch.request(req, Tide.Finch) do
          {:ok, %{status: 200, body: body}} ->
            predictions = body |> Jason.decode!() |> Map.get("predictions") |> Enum.map(&parse_prediction(&1))
            {:ok, predictions}
          {:ok, %{status: code, body: body}} ->
            {:error, "HTTP error #{code}: #{body}"}
          {:error, reason} ->
            {:error, "HTTP error: #{reason}"}
        end
    end)
    res
  end

  def get_nearest_station(latitude, longitude) do
    {:ok,
     Tide.Station
     |> order_by([s], asc: fragment("abs(?)", s.latitude-^latitude) + fragment("abs(?)", s.longitude-^longitude))
     |> limit(1)
     |> Tide.Repo.one()
    }
  end

  def populate_stations() do
    {:ok, stations} = get_stations()
    changesets = Enum.map(stations,
      fn(station) ->
        {:ok, station_local_timezone} = TzWorld.timezone_at({station["longitude"], station["latitude"]})
        station = Map.put(station, "time_zone_name", station_local_timezone)
        Tide.Station.changeset(%Tide.Station{}, station)
      end)
    Tide.Repo.transaction(fn ->
      Enum.each(changesets, fn(cs) -> Tide.Repo.insert(cs) end)
    end)
  end

  def datetime_at_station(station = %Tide.Station{}) do
    DateTime.now!(station.time_zone_name)
  end

  def get_stations() do
    url = "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json"
    params = %{
      "type" => "tidepredictions",
      "units" => "english"
    } |> URI.encode_query

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

  def get_astronomy_times(latitude, longitude, date) do
    url = "https://aa.usno.navy.mil/api/rstt/oneday"
    params = %{
      "date" => Calendar.strftime(date, "%Y-%m-%d"),
      "coords" => "#{latitude},#{longitude}",
    } |> URI.encode_query

    uri = URI.parse(url)

    uri = %{uri | query: params}

    {_cachex_result, res} = Cachex.fetch(:prediction_cache, uri, fn(uri) ->
    req = Finch.build(:get, uri)

    case Finch.request(req, Tide.Finch) do
      {:ok, %{status: 200, body: body}} ->
        res = body |> Jason.decode!() |> parse_astronomy_times
        events = for {key, value} <- res do
          datetime_str = "#{Calendar.strftime(date, "%Y-%m-%d")}T#{value}:00Z"
          {:ok, datetime, _} = DateTime.from_iso8601(datetime_str)
          {key, datetime}
        end
        |> Map.new
        {:ok, events}
      {:ok, %{status: code, body: body}} ->
        {:error, "HTTP error #{code}: #{body}"}
      {:error, reason} ->
        {:error, "HTTP error: #{reason}"}
    end
    end)
    res
  end

  # Parse the sunrise, sunset, moonrise, and moonset times and convert to DateTime
  defp parse_astronomy_times(response) do
    %{
      sunrise: get_in(response, ["properties", "data", "sundata"]) |> Enum.find(fn x -> x["phen"] == "Rise" end) |> Map.get("time"),
      sunset: get_in(response, ["properties", "data", "sundata"]) |> Enum.find(fn x -> x["phen"] == "Set" end) |> Map.get("time"),
      moonrise: get_in(response, ["properties", "data", "moondata"]) |> Enum.find(%{}, fn x -> x["phen"] == "Rise" end) |> Map.get("time"),
      moonset: get_in(response, ["properties", "data", "moondata"]) |> Enum.find(%{}, fn x -> x["phen"] == "Set" end) |> Map.get("time"),
    }
    |> Enum.reject(fn {_key, value} -> value == nil end)
    |> Enum.into(%{})
  end

  def get_sun_times(latitude, longitude, date) do
    url = "https://api.sunrise-sunset.org/json"
    params = %{
      "lat" => latitude,
      "lng" => longitude,
      "date" => date,
      "formatted" => 0
    } |> URI.encode_query
    uri = URI.parse(url)

    uri = %{uri | query: params}

    req = Finch.build(:get, uri)

    case Finch.request(req, Tide.Finch) do
      {:ok, %{status: 200, body: body}} ->
        res = body |> Jason.decode!() |> Map.get("results") |> parse_sun_time
        {:ok, %{sunrise_time: res["sunrise_time"], sunset_time: res["sunset_time"]}}
      {:ok, %{status: code, body: body}} ->
        {:error, "HTTP error #{code}: #{body}"}
      {:error, reason} ->
        {:error, "HTTP error: #{reason}"}
    end

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

  defp parse_sun_time(sun_time) do
    %{
      "sunrise_time" => sun_time["sunrise"],
      "sunset_time" => sun_time["sunset"],
    }
  end


  defp parse_prediction(prediction) do
    {:ok, time, _something} = prediction["t"] |> String.replace(" ", "T") |> Kernel.<>(":00Z") |> DateTime.from_iso8601
    time_truncated =  DateTime.to_unix(time) |> Kernel./(900) |> Kernel.round() |> Kernel.*(900) |> DateTime.from_unix!

    %{
      "t" => time,
      "t_truncated" => time_truncated,
      "v" => prediction["v"],
      "type" => prediction["type"]
    }
  end
end
