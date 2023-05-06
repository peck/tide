defmodule TideWeb.PageController do
  use TideWeb, :controller
  use Timex

  def home(conn, params = %{"station_id" => station_id, "date" => date}) do
    station = Tide.Repo.get_by(Tide.Station, id: station_id)
    {:ok, date} = Date.from_iso8601(date)
    {:ok, %{predictions: predictions, station: station, events: events}} = Tide.get_tide_by_station(station, date)

    next_tide_time = predictions
    |> hd
    |> Map.get("t")

    #rounded_duration_in_seconds = DateTime.diff(next_tide_time, local_time) |> Kernel./(900) |> Kernel.round() |> Kernel.*(900)
    #diurnal_tide_length_in_seconds = 6 * 3600 + 12 * 60 + 30

    #time_to_next_change_humanized = rounded_duration_in_seconds |> Timex.Duration.from_seconds() |> Timex.format_duration(:humanized) |> String.replace(",", " and")

    conn
    |> assign(:predictions, predictions)
    |> assign(:station, station)
    |> assign(:current_time, date)
    |> assign(:sunrise_time, events[:sunrise])
    |> assign(:sunset_time, events[:sunset])
    |> assign(:moonrise_time, events[:moonrise])
    |> assign(:moonset_time, events[:moonset])
    |> render(:not_today, layout: false)
  end

  def home(conn, params = %{"station_id" => station_id}) do
    station = Tide.Repo.get_by(Tide.Station, id: station_id)
    local_time = DateTime.now!(station.time_zone_name)
    {:ok, %{predictions: predictions, station: station, events: events}} = Tide.get_tide_by_station(station, local_time)

    next_tide_time = predictions
    |> hd
    |> Map.get("t")

    rounded_duration_in_seconds = DateTime.diff(next_tide_time, local_time) |> Kernel./(900) |> Kernel.round() |> Kernel.*(900)
    #diurnal_tide_length_in_seconds = 6 * 3600 + 12 * 60 + 30

    time_to_next_change_humanized = rounded_duration_in_seconds |> Timex.Duration.from_seconds() |> Timex.format_duration(:humanized) |> String.replace(",", " and")

    conn
    |> assign(:predictions, predictions)
    |> assign(:station, station)
    |> assign(:time_to_next_change, time_to_next_change_humanized)
    |> assign(:current_time, local_time)
    |> assign(:sunrise_time, events[:sunrise])
    |> assign(:sunset_time, events[:sunset])
    |> assign(:moonrise_time, events[:moonrise])
    |> assign(:moonset_time, events[:moonset])
    |> render(:not_today, layout: false)
  end

  #if we're not given anything, find something
  def home(conn, params = %{}) do
    {:ok, station} = Tide.get_nearest_station(32.231944, -80.735833)
    date = Tide.datetime_at_station(station)
    updated_params = set_default_params(params, %{
          "station_id" => station.id,
                                        })
    home(conn, updated_params)
  end

  def stations(conn, _params = %{}) do
    stations = Tide.Station.get_stations(%{latitude: 32.231944, longitude: -80.735833})
    conn
    |> assign(:stations, stations)
    |> render(:stations, layout: false)
  end

  defp set_default_params(params, defaults) do
    Enum.reduce(defaults, params, fn {key, default_value}, acc ->
      Map.put_new(acc, key, default_value)
    end)
  end
end
